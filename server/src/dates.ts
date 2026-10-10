function isoDate(year: number, month: number, day: number): string | null {
  const d = new Date(Date.UTC(year, month - 1, day))
  if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month - 1 || d.getUTCDate() !== day) return null
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`
}

/**
 * Normalisasi tanggal dari spreadsheet ke "yyyy-MM-dd".
 * Urutan percobaan sama dengan validator di aplikasi
 * (lib/features/import_sheets/domain/row_validator.dart):
 * ISO 8601 → dd/MM/yyyy → MM/dd/yyyy.
 */
export function normalizeDate(value: string): string | null {
  const v = value.trim()
  let m = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ].*)?$/.exec(v)
  if (m) return isoDate(+m[1], +m[2], +m[3])
  m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(v)
  if (m) return isoDate(+m[3], +m[2], +m[1]) ?? isoDate(+m[3], +m[1], +m[2])
  return null
}
