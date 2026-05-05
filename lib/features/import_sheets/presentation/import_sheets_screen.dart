import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'import_sheets_provider.dart';
import 'steps/step1_configure_screen.dart';
import 'steps/step2_preview_screen.dart';
import 'steps/step3_mapping_screen.dart';
import 'steps/step4_validation_screen.dart';
import 'steps/step5_result_screen.dart';

class ImportSheetsScreen extends ConsumerWidget {
  const ImportSheetsScreen({super.key});

  static const _stepLabels = [
    'Konfigurasi',
    'Pratinjau',
    'Pemetaan',
    'Validasi',
    'Hasil',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importSheetsNotifierProvider);
    final currentStep = state.currentStep;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import Data Spreadsheet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Langkah $currentStep dari 5 — ${_stepLabels[currentStep - 1]}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: currentStep / 5,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      body: _StepContent(currentStep: currentStep),
    );
  }
}

class _StepContent extends StatelessWidget {
  final int currentStep;

  const _StepContent({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    switch (currentStep) {
      case 1:
        return const Step1ConfigureScreen();
      case 2:
        return const Step2PreviewScreen();
      case 3:
        return const Step3MappingScreen();
      case 4:
        return const Step4ValidationScreen();
      case 5:
        return const Step5ResultScreen();
      default:
        return const Step1ConfigureScreen();
    }
  }
}
