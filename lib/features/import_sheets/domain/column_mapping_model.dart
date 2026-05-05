class ColumnDefinition {
  final String name;
  final String type;
  final bool required;

  const ColumnDefinition({
    required this.name,
    required this.type,
    required this.required,
  });
}

class ColumnMappingModel {
  final String sourceColumn;
  final String? targetColumn;
  final bool isIgnored;

  const ColumnMappingModel({
    required this.sourceColumn,
    this.targetColumn,
    this.isIgnored = false,
  });

  ColumnMappingModel copyWith({
    String? sourceColumn,
    String? targetColumn,
    bool? isIgnored,
  }) {
    return ColumnMappingModel(
      sourceColumn: sourceColumn ?? this.sourceColumn,
      targetColumn: targetColumn ?? this.targetColumn,
      isIgnored: isIgnored ?? this.isIgnored,
    );
  }
}
