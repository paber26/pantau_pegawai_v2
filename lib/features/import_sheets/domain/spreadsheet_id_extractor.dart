/// Mengekstrak Spreadsheet ID dari URL Google Sheets atau mengembalikan
/// input as-is jika sudah berupa ID langsung.
///
/// - URL format `https://docs.google.com/spreadsheets/d/{ID}/...` → return `{ID}`
/// - String tanpa `/` dan tidak kosong → dianggap ID langsung, return as-is
/// - Input kosong, URL domain lain, atau format tidak valid → return `null`
String? extractSpreadsheetId(String input) {
  if (input.isEmpty) return null;

  // Jika input mengandung '/', coba ekstrak dari URL Google Sheets
  if (input.contains('/')) {
    final regex =
        RegExp(r'https://docs\.google\.com/spreadsheets/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(input);
    if (match != null) {
      return match.group(1);
    }
    // URL dengan '/' tapi bukan Google Sheets → tidak valid
    return null;
  }

  // Tidak mengandung '/' dan tidak kosong → anggap sebagai ID langsung
  return input;
}
