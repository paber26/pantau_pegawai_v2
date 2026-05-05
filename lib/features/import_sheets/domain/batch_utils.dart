/// Membagi [items] menjadi sub-list dengan ukuran maksimal [batchSize].
///
/// Jika [items] kosong, mengembalikan list kosong `[]`.
///
/// Contoh:
/// ```dart
/// splitIntoBatches([1, 2, 3, 4, 5], batchSize: 2)
/// // → [[1, 2], [3, 4], [5]]
/// ```
List<List<T>> splitIntoBatches<T>(List<T> items, {int batchSize = 100}) {
  if (items.isEmpty) return [];

  final batches = <List<T>>[];
  for (int i = 0; i < items.length; i += batchSize) {
    final end = (i + batchSize < items.length) ? i + batchSize : items.length;
    batches.add(items.sublist(i, end));
  }
  return batches;
}
