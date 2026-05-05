class ImportRowError {
  final int rowIndex;
  final Map<String, dynamic> originalData;
  final String message;

  const ImportRowError({
    required this.rowIndex,
    required this.originalData,
    required this.message,
  });
}

class ImportResultModel {
  final int totalProcessed;
  final int successCount;
  final int failedCount;
  final Duration duration;
  final List<ImportRowError> errors;

  const ImportResultModel({
    required this.totalProcessed,
    required this.successCount,
    required this.failedCount,
    required this.duration,
    required this.errors,
  });
}
