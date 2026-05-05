import 'sheet_row_model.dart';

/// Membatasi daftar baris pratinjau hingga maksimal [maxRows] baris.
///
/// Mengembalikan [maxRows] baris pertama dari [rows], atau semua baris
/// jika jumlahnya kurang dari [maxRows].
List<SheetRowModel> limitPreviewRows(
  List<SheetRowModel> rows, {
  int maxRows = 10,
}) {
  return rows.take(maxRows).toList();
}

/// Menghitung jumlah baris data (tidak termasuk header).
///
/// Mengembalikan `totalRowsIncludingHeader - 1`, atau `0` jika input ≤ 0.
int countDataRows(int totalRowsIncludingHeader) {
  return totalRowsIncludingHeader > 0 ? totalRowsIncludingHeader - 1 : 0;
}
