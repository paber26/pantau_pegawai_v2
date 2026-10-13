import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/core/utils/image_url_utils.dart';
import 'package:pantau_pegawai/shared/widgets/drive_image.dart';

void main() {
  test('thumbnail lewat /api/images/thumb, cache terpisah dari foto asli', () {
    final thumb = DriveImage.source('abcDEF123_-xyz', thumbnail: true);
    final full = DriveImage.source('abcDEF123_-xyz', thumbnail: false);

    expect(thumb.url, endsWith('/api/images/thumb?id=abcDEF123_-xyz'));
    expect(full.url, endsWith('/api/images?id=abcDEF123_-xyz'));
    expect(thumb.cacheKey, isNot(full.cacheKey));
    // Cache foto asli tetap memakai kunci lama (file ID) agar tidak diunduh ulang.
    expect(full.cacheKey, 'abcDEF123_-xyz');
  });

  test('file ID tetap terbaca dari URL thumbnail', () {
    final thumb = DriveImage.source('abcDEF123_-xyz', thumbnail: true);
    expect(ImageUrlUtils.extractFileId(thumb.url), 'abcDEF123_-xyz');
  });
}
