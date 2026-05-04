import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../kegiatan/presentation/kegiatan_provider.dart';
import 'laporan_provider.dart';

class UploadLaporanScreen extends ConsumerStatefulWidget {
  final String kegiatanId;

  const UploadLaporanScreen({super.key, required this.kegiatanId});

  @override
  ConsumerState<UploadLaporanScreen> createState() =>
      _UploadLaporanScreenState();
}

class _UploadLaporanScreenState extends ConsumerState<UploadLaporanScreen> {
  final _deskripsiController = TextEditingController();
  File? _selectedImage;
  Uint8List? _webImageBytes; // untuk web preview
  final _picker = ImagePicker();

  @override
  void dispose() {
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _selectedImage = File(picked.path);
        });
      } else {
        setState(() => _selectedImage = File(picked.path));
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: AppColors.primary),
                ),
                title: const Text(AppStrings.ambilFoto),
                subtitle: const Text('Gunakan kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.accent),
                ),
                title: const Text(AppStrings.pilihGaleri),
                subtitle: const Text('Pilih dari galeri foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih foto terlebih dahulu'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = await ref.read(authStateProvider.future);
    if (user == null) return;

    final ok = await ref.read(uploadLaporanNotifierProvider.notifier).upload(
          kegiatanId: widget.kegiatanId,
          imageFile: _selectedImage!,
          pegawaiNama: user.nama,
          deskripsi: _deskripsiController.text.trim().isEmpty
              ? null
              : _deskripsiController.text.trim(),
        );

    if (mounted) {
      if (ok) {
        // Refresh laporan list
        ref.invalidate(myLaporanProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Laporan berhasil dikirim!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else {
        final uploadState = ref.read(uploadLaporanNotifierProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(uploadState.error?.toString() ?? 'Gagal mengirim laporan'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadLaporanNotifierProvider);
    final isLoading = uploadState.isLoading;

    // Ambil judul kegiatan
    final kegiatanAsync = ref.watch(kegiatanNotifierProvider);
    final judulKegiatan = kegiatanAsync.valueOrNull
            ?.firstWhere(
              (k) => k.id == widget.kegiatanId,
              orElse: () => kegiatanAsync.valueOrNull!.first,
            )
            .judul ??
        'Kegiatan';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.uploadLaporan)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info kegiatan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      judulKegiatan,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Foto picker
            GestureDetector(
              onTap: isLoading ? null : _showImageSourceSheet,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 220,
                decoration: BoxDecoration(
                  color: _selectedImage != null
                      ? Colors.black
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedImage != null
                        ? AppColors.primary
                        : AppColors.border,
                    width: _selectedImage != null ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: _buildImagePreview(),
                ),
              ),
            ),

            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: isLoading ? null : _showImageSourceSheet,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Ganti Foto'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Deskripsi
            AppTextField(
              controller: _deskripsiController,
              label: AppStrings.deskripsiLaporan,
              hint: 'Tuliskan deskripsi laporan kegiatan...',
              prefixIcon: Icons.description_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 24),

            // Loading indicator saat upload
            if (isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Mengupload foto ke Google Drive...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            AppButton(
              label: AppStrings.kirimLaporan,
              onPressed: isLoading ? null : _handleSubmit,
              isLoading: isLoading,
              icon: Icons.send_outlined,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 52,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ketuk untuk pilih foto',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kamera atau Galeri',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(
        _webImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Image.file(
      _selectedImage!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
