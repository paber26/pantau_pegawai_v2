import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/drive_image.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../pegawai/presentation/pegawai_provider.dart';
import '../domain/dokumentasi_model.dart';
import 'dokumentasi_provider.dart';

/// Halaman utama: semua dokumentasi semua pegawai + filter
class DokumentasiScreen extends ConsumerStatefulWidget {
  const DokumentasiScreen({super.key});
  @override
  ConsumerState<DokumentasiScreen> createState() => _DokumentasiScreenState();
}

class _DokumentasiScreenState extends ConsumerState<DokumentasiScreen> {
  String? _filterPegawaiId;
  String? _filterProyek;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(adminDokumentasiNotifierProvider);
    final pegawaiList = ref.watch(pegawaiNotifierProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dokumentasi Harian'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () => _showFilterSheet(context, pegawaiList)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.read(adminDokumentasiNotifierProvider.notifier).refresh()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Tambah'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: docsAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(message: e.toString(), onRetry: () => ref.read(adminDokumentasiNotifierProvider.notifier).refresh()),
        data: (allList) {
          var list = allList;
          if (_filterPegawaiId != null) list = list.where((d) => d.userId == _filterPegawaiId).toList();
          if (_filterProyek != null && _filterProyek!.isNotEmpty) {
            list = list.where((d) => d.proyek.toLowerCase().contains(_filterProyek!.toLowerCase())).toList();
          }
          if (list.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.photo_library_outlined, size: 64, color: AppColors.textHint),
              const SizedBox(height: 16),
              const Text('Belum ada dokumentasi', style: TextStyle(color: AppColors.textSecondary)),
            ]));
          }
          final grouped = _groupByDate(list);
          return RefreshIndicator(
            onRefresh: () => ref.read(adminDokumentasiNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return DokDateGroup(tanggal: entry.key, items: entry.value, showPegawai: true);
              },
            ),
          );
        },
      ),
    );
  }

  Map<DateTime, List<DokumentasiModel>> _groupByDate(List<DokumentasiModel> list) {
    final Map<DateTime, List<DokumentasiModel>> grouped = {};
    for (final doc in list) {
      final date = DateTime(doc.tanggalKegiatan.year, doc.tanggalKegiatan.month, doc.tanggalKegiatan.day);
      grouped.putIfAbsent(date, () => []).add(doc);
    }
    return grouped;
  }

  void _showFilterSheet(BuildContext context, List pegawaiList) {
    String? tempPegawaiId = _filterPegawaiId;
    String? tempProyek = _filterProyek;
    DateTime? tempFrom = _filterFrom;
    DateTime? tempTo = _filterTo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Filter Dokumentasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: tempPegawaiId,
                  decoration: InputDecoration(labelText: 'Pegawai', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Pegawai')),
                    ...pegawaiList.map((p) => DropdownMenuItem(value: p.id as String, child: Text(p.nama as String))),
                  ],
                  onChanged: (v) => setModal(() => tempPegawaiId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: tempProyek,
                  decoration: InputDecoration(labelText: 'Kegiatan/Proyek', hintText: 'Cari nama kegiatan...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  onChanged: (v) => setModal(() => tempProyek = v.isEmpty ? null : v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: InkWell(
                    onTap: () async {
                      final p = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (p != null) setModal(() => tempFrom = p);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'Dari', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(tempFrom != null ? AppDateUtils.formatDate(tempFrom!) : 'Pilih', style: const TextStyle(fontSize: 14)),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: InkWell(
                    onTap: () async {
                      final p = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (p != null) setModal(() => tempTo = p);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'Sampai', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(tempTo != null ? AppDateUtils.formatDate(tempTo!) : 'Pilih', style: const TextStyle(fontSize: 14)),
                    ),
                  )),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () {
                      setState(() { _filterPegawaiId = null; _filterProyek = null; _filterFrom = null; _filterTo = null; });
                      ref.read(adminDokumentasiNotifierProvider.notifier).applyFilter();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () {
                      setState(() { _filterPegawaiId = tempPegawaiId; _filterProyek = tempProyek; _filterFrom = tempFrom; _filterTo = tempTo; });
                      ref.read(adminDokumentasiNotifierProvider.notifier).applyFilter(fromDate: tempFrom, toDate: tempTo);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Terapkan'),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DokumentasiFormSheet(),
    );
  }
}

/// Halaman riwayat: hanya milik sendiri
class RiwayatDokumentasiScreen extends ConsumerWidget {
  const RiwayatDokumentasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(myDokumentasiNotifierProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Saya'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.read(myDokumentasiNotifierProvider.notifier).refresh())],
      ),
      body: docsAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history, size: 64, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text('Halo, ${user?.nama ?? "Pegawai"}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Belum ada riwayat dokumentasi.', style: TextStyle(color: AppColors.textSecondary)),
            ]));
          }
          final grouped = <DateTime, List<DokumentasiModel>>{};
          for (final doc in list) {
            final date = DateTime(doc.tanggalKegiatan.year, doc.tanggalKegiatan.month, doc.tanggalKegiatan.day);
            grouped.putIfAbsent(date, () => []).add(doc);
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(myDokumentasiNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return DokDateGroup(tanggal: entry.key, items: entry.value, showPegawai: false);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Form sheet tambah dokumentasi
class DokumentasiFormSheet extends ConsumerStatefulWidget {
  const DokumentasiFormSheet({super.key});
  @override
  ConsumerState<DokumentasiFormSheet> createState() => _DokumentasiFormSheetState();
}

class _DokumentasiFormSheetState extends ConsumerState<DokumentasiFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _proyekController = TextEditingController();
  final _catatanController = TextEditingController();
  final _linkController = TextEditingController();
  DateTime _tanggal = DateTime.now();
  File? _imageFile;
  Uint8List? _webImageBytes;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _proyekController.dispose();
    _catatanController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() { _webImageBytes = bytes; _imageFile = File(picked.path); });
      } else {
        setState(() => _imageFile = File(picked.path));
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary), title: const Text('Ambil Foto'), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent), title: const Text('Pilih dari Galeri'), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
        if (_imageFile != null)
          ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.error), title: const Text('Hapus Foto', style: TextStyle(color: AppColors.error)), onTap: () { Navigator.pop(ctx); setState(() { _imageFile = null; _webImageBytes = null; }); }),
      ])),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final errorMsg = await ref.read(myDokumentasiNotifierProvider.notifier).tambah(
      proyek: _proyekController.text.trim(),
      tanggalKegiatan: _tanggal,
      imageFile: kIsWeb ? null : _imageFile,
      imageBytes: kIsWeb ? _webImageBytes : null,
      catatan: _catatanController.text.trim().isEmpty ? null : _catatanController.text.trim(),
      link: _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
    );
    ref.read(adminDokumentasiNotifierProvider.notifier).refresh();
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMsg == null ? 'Dokumentasi berhasil disimpan!' : 'Gagal: $errorMsg'),
        backgroundColor: errorMsg == null ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Tambah Dokumentasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _imageFile != null ? AppColors.primary : AppColors.border, width: _imageFile != null ? 2 : 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _imageFile == null
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.primary.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            const Text('Tambah Foto (opsional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ])
                        : (kIsWeb && _webImageBytes != null
                            ? Image.memory(_webImageBytes!, fit: BoxFit.cover, width: double.infinity)
                            : Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _proyekController,
                decoration: InputDecoration(labelText: 'Proyek / Kegiatan *', hintText: 'Contoh: Rapat Koordinasi, SENYUM', prefixIcon: const Icon(Icons.work_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _tanggal, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) setState(() => _tanggal = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: 'Tanggal Kegiatan *', prefixIcon: const Icon(Icons.calendar_today_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text(AppDateUtils.formatDate(_tanggal), style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _catatanController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Catatan', hintText: 'Deskripsi kegiatan...', prefixIcon: const Icon(Icons.notes_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: 'Link (opsional)', hintText: 'https://', prefixIcon: const Icon(Icons.link_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              if (_isLoading) ...[const LinearProgressIndicator(), const SizedBox(height: 8)],
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleSubmit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan Dokumentasi'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Group dokumentasi per tanggal
class DokDateGroup extends ConsumerWidget {
  final DateTime tanggal;
  final List<DokumentasiModel> items;
  final bool showPegawai;

  const DokDateGroup({super.key, required this.tanggal, required this.items, required this.showPegawai});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isToday = tanggal.year == now.year && tanggal.month == now.month && tanggal.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = tanggal.year == yesterday.year && tanggal.month == yesterday.month && tanggal.day == yesterday.day;
    final label = isToday ? 'Hari Ini' : isYesterday ? 'Kemarin' : DateFormat('d MMMM yyyy', 'id_ID').format(tanggal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isToday ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isToday ? Colors.white : AppColors.primary)),
            ),
            const SizedBox(width: 8),
            const Expanded(child: Divider(color: AppColors.divider, height: 1)),
            const SizedBox(width: 8),
            Text('${items.length} entri', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ]),
        ),
        ...items.map((doc) => DokCard(doc: doc, showPegawai: showPegawai)),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Card satu item dokumentasi
class DokCard extends ConsumerWidget {
  final DokumentasiModel doc;
  final bool showPegawai;

  const DokCard({super.key, required this.doc, required this.showPegawai});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isOwn = currentUser?.id == doc.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: doc.imageUrl != null ? () => _showFullImage(context, doc.imageUrl!) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: doc.imageUrl != null
                    ? DriveImage(imageUrl: doc.imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                    : _noImage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showPegawai && doc.pegawaiNama != null)
                    Text(doc.pegawaiNama!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                  Text(doc.proyek, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (doc.catatan != null)
                    Text(doc.catatan!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.access_time, size: 11, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(DateFormat('HH:mm').format(doc.createdAt.toLocal()), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    if (doc.link != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(doc.link!);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: const Row(children: [
                          Icon(Icons.link, size: 11, color: AppColors.primary),
                          SizedBox(width: 2),
                          Text('Link', style: TextStyle(fontSize: 11, color: AppColors.primary, decoration: TextDecoration.underline)),
                        ]),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            if (isOwn)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'hapus') {
                    final confirm = await showConfirmDialog(context, title: 'Hapus Dokumentasi', message: 'Hapus dokumentasi "\${doc.proyek}"?');
                    if (confirm == true && context.mounted) {
                      await ref.read(myDokumentasiNotifierProvider.notifier).hapus(doc.id);
                      ref.read(adminDokumentasiNotifierProvider.notifier).refresh();
                    }
                  }
                },
                itemBuilder: (_) => [const PopupMenuItem(value: 'hapus', child: Text('Hapus', style: TextStyle(color: AppColors.error)))],
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textHint),
              ),
          ],
        ),
      ),
    );
  }

  Widget _noImage() => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.image_outlined, color: AppColors.textHint, size: 24),
  );

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(child: DriveImage(imageUrl: imageUrl, width: double.infinity, height: double.infinity, fit: BoxFit.contain)),
          Positioned(top: 40, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context))),
        ]),
      ),
    );
  }
}
