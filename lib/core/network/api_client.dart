import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import '../utils/date_utils.dart';
import 'session_store.dart';

/// Klien HTTP untuk API PantauPegawai di VPS (pengganti SupabaseClient).
///
/// - Menempelkan `Authorization: Bearer <token>` dari [SessionStore].
/// - Error dari server (`{"error": "..."}`) diubah menjadi [AppException].
/// - Respons 401 pada request yang membawa token berarti sesi sudah tidak
///   berlaku: sesi dihapus sehingga aplikasi kembali ke halaman login.
class ApiClient {
  ApiClient(this._session, {http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConstants.apiUrl;

  final SessionStore _session;
  final http.Client _http;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 60);

  Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Map<String, String?>? query}) =>
      _send('DELETE', path, query: query);

  /// Upload foto ke Google Drive lewat API. Foto disimpan di folder
  /// `{nama pegawai}/{tanggal}`; mengembalikan URL gambar.
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required DateTime tanggal,
  }) async {
    final filename = 'foto_${AppDateUtils.toTimestamp(DateTime.now())}.jpg';
    final request = http.MultipartRequest('POST', _uri('/api/uploads'))
      ..headers.addAll(_headers(json: false))
      ..fields['tanggal'] = AppDateUtils.toFolderDate(tanggal)
      ..fields['filename'] = filename
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final sentWithToken = _session.token != null;
    final response = await _guard(
      () async => http.Response.fromStream(await _http.send(request)),
    );
    final data = await _decode(response, sentWithToken);
    return (data as Map<String, dynamic>)['image_url'] as String;
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    final params = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null) e.key: e.value!,
    };
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_session.token != null) 'Authorization': 'Bearer ${_session.token}',
      };

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
  }) async {
    // Content-Type JSON hanya bila ada body: server menolak (400) request
    // ber-Content-Type JSON yang body-nya kosong, mis. DELETE dan logout.
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers(json: body != null));
    if (body != null) request.body = jsonEncode(body);

    final sentWithToken = _session.token != null;
    final response = await _guard(
      () async => http.Response.fromStream(await _http.send(request)),
    );
    return _decode(response, sentWithToken);
  }

  Future<http.Response> _guard(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw const AppException(
        'Koneksi ke server timeout. Silakan coba lagi.',
        code: 'timeout',
      );
    } on http.ClientException {
      throw const AppException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        code: 'network_error',
      );
    }
  }

  Future<dynamic> _decode(http.Response response, bool sentWithToken) async {
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        data = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : 'Terjadi kesalahan (status ${response.statusCode}).';

    if (response.statusCode == 401 && sentWithToken) {
      await _session.clear();
    }
    throw AppException(message, code: '${response.statusCode}');
  }
}
