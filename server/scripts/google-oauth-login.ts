/**
 * Login sekali dengan akun Gmail pemilik folder Drive, untuk mendapatkan
 * refresh token yang dipakai server saat mengunggah foto
 * (GOOGLE_OAUTH_REFRESH_TOKEN). Lihat docs/13-deploy-vps.md.
 *
 * Butuh GOOGLE_OAUTH_CLIENT_ID dan GOOGLE_OAUTH_CLIENT_SECRET (OAuth client
 * tipe "Desktop app") di .env.
 *
 * Langkah 1 — cetak URL izin Google:
 *   docker compose run --rm api node dist/scripts/google-oauth-login.js
 *
 * Langkah 2 — buka URL itu di browser, login dengan akun pemilik folder, lalu
 * izinkan. Browser diarahkan ke http://localhost:8765/?code=... dan menampilkan
 * "tidak dapat dijangkau" (memang begitu). Salin URL lengkap dari address bar:
 *   docker compose run --rm api node dist/scripts/google-oauth-login.js "<URL>"
 *
 * Skrip menukar kode, memeriksa akun dan akses ke folder root, lalu mencetak
 * baris GOOGLE_OAUTH_REFRESH_TOKEN=... untuk disalin ke .env.
 */
import path from "node:path"
import { fileURLToPath } from "node:url"

import { OAuth2Client } from "google-auth-library"

/** Redirect loopback; untuk client tipe Desktop tidak perlu didaftarkan. */
export const REDIRECT_URI = "http://localhost:8765"
const DRIVE_SCOPE = "https://www.googleapis.com/auth/drive"
const DRIVE_API = "https://www.googleapis.com/drive/v3"

/** Ambil kode otorisasi dari URL hasil redirect, atau dari kode yang ditempel langsung. */
export function extractAuthCode(input: string): string {
  const text = input.trim()
  if (!text) throw new Error("Kode atau URL kosong.")
  if (!/^https?:\/\//i.test(text)) return decodeURIComponent(text)

  const url = new URL(text)
  const error = url.searchParams.get("error")
  if (error) throw new Error(`Google menolak izin: ${error}`)
  const code = url.searchParams.get("code")
  if (!code) throw new Error("URL tidak berisi parameter code. Salin URL lengkap dari address bar.")
  return code
}

function formatGb(bytes: string | undefined): string {
  return bytes ? `${(Number(bytes) / 1024 ** 3).toFixed(1)} GB` : "tanpa batas"
}

async function main(input: string | undefined) {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID?.trim()
  const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET?.trim()
  if (!clientId || !clientSecret) {
    throw new Error("Isi GOOGLE_OAUTH_CLIENT_ID dan GOOGLE_OAUTH_CLIENT_SECRET di .env terlebih dahulu.")
  }
  const client = new OAuth2Client({ clientId, clientSecret, redirectUri: REDIRECT_URI })

  if (!input) {
    const url = client.generateAuthUrl({ access_type: "offline", prompt: "consent", scope: [DRIVE_SCOPE] })
    console.log("1. Buka URL ini di browser dan login dengan akun Gmail PEMILIK folder Drive foto:\n")
    console.log(url)
    console.log(
      '\n2. Bila muncul "Google belum memverifikasi aplikasi ini": pilih Lanjutan → Buka (aplikasi milik sendiri).' +
        "\n3. Setelah mengizinkan, browser membuka http://localhost:8765/?code=... dan menampilkan" +
        "\n   halaman tidak dapat dijangkau. Itu normal. Salin URL lengkap dari address bar, lalu jalankan:" +
        '\n\n   docker compose run --rm api node dist/scripts/google-oauth-login.js "<URL yang disalin>"\n'
    )
    return
  }

  const { tokens } = await client.getToken(extractAuthCode(input))
  if (!tokens.refresh_token) {
    throw new Error(
      "Google tidak mengirim refresh token. Cabut akses aplikasi di https://myaccount.google.com/permissions, " +
        "lalu ulangi dari langkah 1."
    )
  }
  client.setCredentials(tokens)

  const about = await client.request<{
    user: { emailAddress: string }
    storageQuota: { limit?: string; usage: string }
  }>({ url: `${DRIVE_API}/about?fields=user(emailAddress),storageQuota(limit,usage)` })
  console.log(`Akun   : ${about.data.user.emailAddress}`)
  console.log(`Kuota  : ${formatGb(about.data.storageQuota.usage)} terpakai dari ${formatGb(about.data.storageQuota.limit)}`)

  const rootFolderId = process.env.GOOGLE_DRIVE_ROOT_FOLDER_ID
  if (rootFolderId) {
    const folder = await client.request<{ name: string; capabilities?: { canAddChildren?: boolean } }>({
      url: `${DRIVE_API}/files/${encodeURIComponent(rootFolderId)}?fields=name,capabilities(canAddChildren)&supportsAllDrives=true`
    })
    if (folder.data.capabilities?.canAddChildren) {
      console.log(`Folder : "${folder.data.name}" bisa ditulis oleh akun ini ✓`)
    } else {
      console.warn(`⚠ Akun ini tidak bisa menambah file ke folder "${folder.data.name}". Login dengan akun pemilik folder.`)
    }
  }

  console.log("\nTambahkan baris berikut ke file .env di VPS (rahasia, jangan dibagikan):\n")
  console.log(`GOOGLE_OAUTH_REFRESH_TOKEN=${tokens.refresh_token}`)
  console.log("\nLalu jalankan: docker compose up -d api")
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main(process.argv[2]).catch((err: unknown) => {
    const detail = (err as { response?: { data?: unknown } }).response?.data
    console.error(`Gagal: ${err instanceof Error ? err.message : String(err)}`)
    if (detail) console.error(JSON.stringify(detail))
    process.exit(1)
  })
}
