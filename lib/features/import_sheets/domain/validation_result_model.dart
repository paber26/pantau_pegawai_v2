class RowValidationError {
  final int rowIndex;
  final String columnName;
  final String value;
  final String message;

  const RowValidationError({
    required this.rowIndex,
    required this.columnName,
    required this.value,
    required this.message,
  });
}

class ValidationResultModel {
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final List<RowValidationError> errors;

  const ValidationResultModel({
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.errors,
  });
}
