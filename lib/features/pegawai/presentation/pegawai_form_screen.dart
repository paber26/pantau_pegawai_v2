import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'pegawai_provider.dart';

class PegawaiFormScreen extends ConsumerStatefulWidget {
  final String? pegawaiId;

  const PegawaiFormScreen({super.key, this.pegawaiId});

  bool get isEdit => pegawaiId != null;

  @override
  ConsumerState<PegawaiFormScreen> createState() => _PegawaiFormScreenState();
}

class _PegawaiFormScreenState extends ConsumerState<PegawaiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _unitKerjaController = TextEditingController();
  String _selectedRole = 'pegawai';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) _loadData();
  }

  Future<void> _loadData() async {
    final pegawai =
        await ref.read(pegawaiRepositoryProvider).getById(widget.pegawaiId!);
    if (mounted) {
      _namaController.text = pegawai.nama;
      _emailController.text = pegawai.email;
      _jabatanController.text = pegawai.jabatan ?? '';
      _unitKerjaController.text = pegawai.unitKerja ?? '';
      setState(() => _selectedRole = pegawai.role);
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _jabatanController.dispose();
    _unitKerjaController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? errorMsg;
    if (widget.isEdit) {
      errorMsg = await ref.read(pegawaiNotifierProvider.notifier).updatePegawai(
            id: widget.pegawaiId!,
            nama: _namaController.text.trim(),
            jabatan: _jabatanController.text.trim().isEmpty
                ? null
                : _jabatanController.text.trim(),
            unitKerja: _unitKerjaController.text.trim().isEmpty
                ? null
                : _unitKerjaController.text.trim(),
            role: _selectedRole,
          );
    } else {
      errorMsg = await ref.read(pegawaiNotifierProvider.notifier).create(
            nama: _namaController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            jabatan: _jabatanController.text.trim().isEmpty
                ? null
                : _jabatanController.text.trim(),
            unitKerja: _unitKerjaController.text.trim().isEmpty
                ? null
                : _unitKerjaController.text.trim(),
            role: _selectedRole,
          );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(errorMsg == null ? AppStrings.berhasil : 'Gagal: $errorMsg'),
          backgroundColor:
              errorMsg == null ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      if (errorMsg == null) context.pop();
    }
  }

  /// Dialog ubah password
  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => _ResetPasswordDialog(
        pegawaiId: widget.pegawaiId!,
        pegawaiNama: _namaController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isEdit ? AppStrings.editPegawai : AppStrings.tambahPegawai),
        actions: [
          // Tombol ubah password hanya di mode edit
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.lock_reset),
              tooltip: 'Ubah Password',
              onPressed: _showResetPasswordDialog,
            ),
        ],
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
                  controller: _namaController,
                  label: AppStrings.namaPegawai,
                  hint: 'Masukkan nama lengkap',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => Validators.required(v, fieldName: 'Nama'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailController,
                  label: AppStrings.email,
                  hint: 'nama@instansi.go.id',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  enabled: !widget.isEdit,
                  validator: widget.isEdit ? null : Validators.email,
                ),
                if (!widget.isEdit) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    label: AppStrings.password,
                    hint: 'Minimal 6 karakter',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: Validators.password,
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  controller: _jabatanController,
                  label: AppStrings.jabatan,
                  hint: 'Contoh: Staf Statistik',
                  prefixIcon: Icons.work_outline,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _unitKerjaController,
                  label: AppStrings.unitKerja,
                  hint: 'Contoh: Seksi Produksi',
                  prefixIcon: Icons.business_outlined,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: InputDecoration(
                    labelText: AppStrings.role,
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pegawai', child: Text('Pegawai')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: AppStrings.simpan,
                  onPressed: _isLoading ? null : _handleSubmit,
                  isLoading: _isLoading,
                ),

                // Tombol ubah password (alternatif di bawah form)
                if (widget.isEdit) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showResetPasswordDialog,
                    icon: const Icon(Icons.lock_reset, size: 18),
                    label: const Text('Ubah Password'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog untuk ubah password pegawai
class _ResetPasswordDialog extends ConsumerStatefulWidget {
  final String pegawaiId;
  final String pegawaiNama;

  const _ResetPasswordDialog({
    required this.pegawaiId,
    required this.pegawaiNama,
  });

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final errorMsg =
        await ref.read(pegawaiNotifierProvider.notifier).resetPassword(
              userId: widget.pegawaiId,
              newPassword: _newPasswordController.text,
            );

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg == null
                ? 'Password ${widget.pegawaiNama} berhasil diubah'
                : 'Gagal: $errorMsg',
          ),
          backgroundColor:
              errorMsg == null ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_reset, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ubah Password\n${widget.pegawaiNama}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                hintText: 'Minimal 6 karakter',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password',
                hintText: 'Ulangi password baru',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Konfirmasi password wajib diisi';
                }
                if (v != _newPasswordController.text) {
                  return 'Password tidak cocok';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleReset,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Ubah Password'),
        ),
      ],
    );
  }
}
