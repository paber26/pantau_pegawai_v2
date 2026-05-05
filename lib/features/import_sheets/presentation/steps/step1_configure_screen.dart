import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/spreadsheet_id_extractor.dart';
import '../import_sheets_provider.dart';

class Step1ConfigureScreen extends ConsumerStatefulWidget {
  const Step1ConfigureScreen({super.key});

  @override
  ConsumerState<Step1ConfigureScreen> createState() =>
      _Step1ConfigureScreenState();
}

class _Step1ConfigureScreenState extends ConsumerState<Step1ConfigureScreen> {
  final _controller = TextEditingController();
  String? _inlineError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final extracted = extractSpreadsheetId(value.trim());
    setState(() {
      _inlineError = value.trim().isEmpty
          ? null
          : extracted == null
              ? 'URL atau Spreadsheet ID tidak valid.'
              : null;
    });
  }

  Future<void> _onLoadSheet() async {
    final input = _controller.text.trim();
    final id = extractSpreadsheetId(input);
    if (id == null) return;

    final notifier = ref.read(importSheetsNotifierProvider.notifier);
    notifier.setSpreadsheetId(id);
    await notifier.loadSheetList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importSheetsNotifierProvider);
    final input = _controller.text.trim();
    final extractedId = extractSpreadsheetId(input);
    final isButtonEnabled =
        !state.isLoading && extractedId != null && _inlineError == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Konfigurasi Sumber Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Masukkan URL Google Spreadsheet atau Spreadsheet ID langsung.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            enabled: !state.isLoading,
            decoration: InputDecoration(
              labelText: 'URL atau Spreadsheet ID',
              hintText:
                  'https://docs.google.com/spreadsheets/d/... atau ID langsung',
              errorText: _inlineError,
              prefixIcon: const Icon(Icons.link_outlined),
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isButtonEnabled ? _onLoadSheet : null,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Muat Sheet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: AppColors.border,
                ),
              ),
            ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.error.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
