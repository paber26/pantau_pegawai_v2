class SheetMetadataModel {
  final String sheetId;
  final String title;
  final int index;

  const SheetMetadataModel({
    required this.sheetId,
    required this.title,
    required this.index,
  });

  factory SheetMetadataModel.fromMap(Map<String, dynamic> map) {
    final props = map['properties'] as Map<String, dynamic>;
    return SheetMetadataModel(
      sheetId: props['sheetId'].toString(),
      title: props['title'] as String,
      index: props['index'] as int,
    );
  }
}
