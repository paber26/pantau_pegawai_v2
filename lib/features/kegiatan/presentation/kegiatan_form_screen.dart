import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'kegiatan_provider.dart';

class KegiatanFormScreen extends ConsumerStatefulWidget {
  final String? kegiatanId;

  const KegiatanFormScreen({super.key, this.kegiatanId});

  bool get isEdit => kegiatanId != null;

  @override
  ConsumerState<KegiatanFormScreen> createState() => _KegiatanFormScreenState();
}

class _KegiatanFormScreenState extends ConsumerState<KegiatanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  DateTime? _selectedDeadline;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) _loadData();
  }

  Future<void> _loadData() async {
    final kegiatan = await ref
        .read(kegiatanRepositoryProvider)
        .getById(widget.kegiatanId!);
    if (mounted) {
      _judulController.text = kegiatan.judul;
      _deskripsiController.text = kegiatan.deskripsi ?? '';
      setState(() => _selectedDeadline = kegiatan.deadline);
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDeadline = picked);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih deadline terlebih dahulu'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool ok;
    if (widget.isEdit) {
      ok = await ref.read(kegiatanNotifierProvider.notifier).updateKegiatan(
            id: widget.kegiatanId!,
            judul: _judulController.text.trim(),
            deskripsi: _deskripsiController.text.trim().isEmpty
                ? null
                : _deskripsiController.text.trim(),
            deadline: _selectedDeadline!,
          );
    } else {
      ok = await ref.read(kegiatanNotifierProvider.notifier).create(
            judul: _judulController.text.trim(),
            deskripsi: _deskripsiController.text.trim().isEmpty
                ? null
                : _deskripsiController.text.trim(),
            deadline: _selectedDeadline!,
          );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? AppStrings.berhasil : AppStrings.gagal),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
      if (ok) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit
            ? AppStrings.editKegiatan
            : AppStrings.tambahKegiatan),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _judulController,
                  label: AppStrings.judulKegiatan,
                  hint: 'Masukkan judul kegiatan',
                  prefixIcon: Icons.assignment_outlined,
                  validator: (v) =>
                      Validators.required(v, fieldName: 'Judul'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _deskripsiController,
                  label: AppStrings.deskripsiKegiatan,
                  hint: 'Deskripsi kegiatan (opsional)',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                // Deadline picker
                InkWell(
                  onTap: _pickDeadline,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppStrings.deadline,
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _selectedDeadline != null
                          ? AppDateUtils.formatDate(_selectedDeadline!)
                          : 'Pilih tanggal deadline',
                      style: TextStyle(
                        color: _selectedDeadline != null
                            ? null
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: AppStrings.simpan,
                  onPressed: _isLoading ? null : _handleSubmit,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
