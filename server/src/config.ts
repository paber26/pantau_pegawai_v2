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
  /**
   * OAuth akun Gmail pemilik folder Drive, dipakai untuk upload. Service account
   * tidak punya kuota penyimpanan sehingga tidak bisa memiliki file di My Drive
   * akun Gmail biasa. `null` = upload tetap memakai service account.
   */
  googleOAuth: GoogleOAuthConfig | null
  /** Folder berisi backup harian (read-only) yang disalin ke Google Drive. `null` = tidak disalin. */
  backupDir: string | null
  /** Kunci VAPID untuk notifikasi web (pengingat harian). `null` = pengingat tidak aktif. */
  vapid: VapidConfig | null
  /** Jadwal pengingat harian, menurut zona waktu `appTimezone`. */
  reminder: ReminderConfig
}

export interface GoogleOAuthConfig {
  clientId: string
  clientSecret: string
  refreshToken: string
}

export interface VapidConfig {
  publicKey: string
  privateKey: string
  /** Kontak pengirim untuk layanan push (`mailto:` atau URL https). */
  subject: string
}

export interface ReminderConfig {
  /** Jam kirim "HH:MM". */
  time: string
  /** Hari kirim, 1 = Senin ... 7 = Minggu. */
  days: number[]
}

function required(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`Environment variable ${name} belum diset`)
  return value
}

export function loadConfig(): Config {
  const publicApiUrl = required("PUBLIC_API_URL").replace(/\/+$/, "")
  return {
    port: Number(process.env.PORT ?? 3000),
    databaseUrl: required("DATABASE_URL"),
    publicApiUrl,
    corsOrigins: (process.env.CORS_ORIGINS ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean),
    sessionTtlDays: Number(process.env.SESSION_TTL_DAYS ?? 30),
    appTimezone: process.env.APP_TIMEZONE || "Asia/Makassar",
    googleServiceAccountFile: process.env.GOOGLE_SERVICE_ACCOUNT_FILE || null,
    googleDriveRootFolderId: process.env.GOOGLE_DRIVE_ROOT_FOLDER_ID || null,
    googleOAuth: googleOAuthFromEnv(process.env),
    backupDir: process.env.BACKUP_DIR || null,
    vapid: vapidFromEnv(process.env, publicApiUrl),
    reminder: reminderFromEnv(process.env)
  }
}

/** Kunci publik & privat harus terisi keduanya; subjek default = URL publik API. */
export function vapidFromEnv(env: NodeJS.ProcessEnv, publicApiUrl: string): VapidConfig | null {
  const publicKey = env.VAPID_PUBLIC_KEY?.trim() ?? ""
  const privateKey = env.VAPID_PRIVATE_KEY?.trim() ?? ""
  if (publicKey && privateKey) return { publicKey, privateKey, subject: env.VAPID_SUBJECT?.trim() || publicApiUrl }
  if (publicKey || privateKey) {
    console.warn("VAPID_PUBLIC_KEY dan VAPID_PRIVATE_KEY harus diisi keduanya; pengingat harian tidak aktif.")
  }
  return null
}

const DEFAULT_REMINDER: ReminderConfig = { time: "15:00", days: [1, 2, 3, 4, 5] }

/** REMINDER_TIME="15:00", REMINDER_DAYS="1-5" atau "1,2,3,4,5,6" (1 = Senin). Nilai rusak → default + peringatan. */
export function reminderFromEnv(env: NodeJS.ProcessEnv): ReminderConfig {
  const timeRaw = env.REMINDER_TIME?.trim() || DEFAULT_REMINDER.time
  const time = /^([01]\d|2[0-3]):[0-5]\d$/.test(timeRaw) ? timeRaw : null
  if (!time) console.warn(`REMINDER_TIME "${timeRaw}" tidak valid (format HH:MM); memakai ${DEFAULT_REMINDER.time}.`)

  const daysRaw = env.REMINDER_DAYS?.trim() || "1-5"
  const days = new Set<number>()
  let daysValid = true
  for (const part of daysRaw.split(",").map((p) => p.trim())) {
    const range = /^([1-7])(?:-([1-7]))?$/.exec(part)
    if (!range) {
      daysValid = false
      break
    }
    const from = Number(range[1])
    const to = Number(range[2] ?? range[1])
    for (let d = from; d <= to; d++) days.add(d)
  }
  if (!daysValid || days.size === 0) {
    console.warn(`REMINDER_DAYS "${daysRaw}" tidak valid (mis. 1-5 atau 1,2,3,4,5,6); memakai Senin-Jumat.`)
  }

  return {
    time: time ?? DEFAULT_REMINDER.time,
    days: daysValid && days.size > 0 ? [...days].sort((a, b) => a - b) : DEFAULT_REMINDER.days
  }
}

/** Ketiga variabel GOOGLE_OAUTH_* harus terisi; bila hanya sebagian, abaikan dengan peringatan. */
export function googleOAuthFromEnv(env: NodeJS.ProcessEnv): GoogleOAuthConfig | null {
  const clientId = env.GOOGLE_OAUTH_CLIENT_ID?.trim() ?? ""
  const clientSecret = env.GOOGLE_OAUTH_CLIENT_SECRET?.trim() ?? ""
  const refreshToken = env.GOOGLE_OAUTH_REFRESH_TOKEN?.trim() ?? ""
  if (clientId && clientSecret && refreshToken) return { clientId, clientSecret, refreshToken }
  if (clientId || clientSecret || refreshToken) {
    console.warn(
      "GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET, dan GOOGLE_OAUTH_REFRESH_TOKEN harus diisi semua; " +
        "upload foto tetap memakai service account."
    )
  }
  return null
}
