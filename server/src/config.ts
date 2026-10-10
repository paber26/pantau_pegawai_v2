/**
 * Konfigurasi API dibaca dari environment variables.
 * Lihat `.env.example` di root repository untuk daftar lengkapnya.
 */

export interface Config {
  port: number
  databaseUrl: string
  /** URL publik API, dipakai untuk membentuk URL gambar (mis. https://api.domain.go.id). */
  publicApiUrl: string
  /** Origin yang boleh memanggil API dari browser. Mendukung wildcard port: http://localhost:* */
  corsOrigins: string[]
  /** Lama sesi login (hari). Diperpanjang otomatis selama dipakai. */
  sessionTtlDays: number
  /** Zona waktu kantor untuk menentukan "hari ini" (dashboard). */
  appTimezone: string
  googleServiceAccountFile: string | null
  googleDriveRootFolderId: string | null
}

function required(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`Environment variable ${name} belum diset`)
  return value
}

export function loadConfig(): Config {
  return {
    port: Number(process.env.PORT ?? 3000),
    databaseUrl: required("DATABASE_URL"),
    publicApiUrl: required("PUBLIC_API_URL").replace(/\/+$/, ""),
    corsOrigins: (process.env.CORS_ORIGINS ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean),
    sessionTtlDays: Number(process.env.SESSION_TTL_DAYS ?? 30),
    appTimezone: process.env.APP_TIMEZONE || "Asia/Makassar",
    googleServiceAccountFile: process.env.GOOGLE_SERVICE_ACCOUNT_FILE || null,
    googleDriveRootFolderId: process.env.GOOGLE_DRIVE_ROOT_FOLDER_ID || null
  }
}
