/**
 * Akses Google Drive memakai Service Account (pengganti Edge Function
 * `upload-to-drive` dan `image-proxy`).
 *
 * Kredensial dibaca dari file JSON service account (GOOGLE_SERVICE_ACCOUNT_FILE).
 * Token akses di-cache oleh google-auth-library sampai hampir kedaluwarsa.
 */
import { readFileSync } from "node:fs"
import { Readable } from "node:stream"

import { JWT } from "google-auth-library"

const DRIVE_API = "https://www.googleapis.com/drive/v3"
const DRIVE_UPLOAD_API = "https://www.googleapis.com/upload/drive/v3"
const FOLDER_MIME = "application/vnd.google-apps.folder"
const FOLDER_CACHE_TTL_MS = 60 * 60 * 1000

export interface DriveImage {
  stream: Readable
  contentType: string
  contentLength: string | null
}

export interface DriveService {
  /** Upload file ke ROOT/{folderPath...}/filename. Mengembalikan file ID. */
  uploadFile(params: { bytes: Buffer; filename: string; mimeType: string; folderPath: string[] }): Promise<string>
  /** Ambil isi gambar. `null` bila file tidak ada atau bukan gambar. */
  getImage(fileId: string): Promise<DriveImage | null>
}

/** Escape nilai untuk query Drive (`name='...'`). Nama seperti "Ma'ruf" tetap aman. */
export function escapeDriveQuery(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/'/g, "\\'")
}

export class GoogleDriveService implements DriveService {
  private readonly auth: JWT
  private readonly folderCache = new Map<string, { id: Promise<string>; expires: number }>()

  constructor(
    serviceAccountFile: string,
    private readonly rootFolderId: string
  ) {
    const credentials = JSON.parse(readFileSync(serviceAccountFile, "utf8")) as {
      client_email: string
      private_key: string
    }
    this.auth = new JWT({
      email: credentials.client_email,
      key: credentials.private_key,
      scopes: ["https://www.googleapis.com/auth/drive"]
    })
  }

  private async authHeader(): Promise<Record<string, string>> {
    const { token } = await this.auth.getAccessToken()
    if (!token) throw new Error("Gagal mendapatkan access token Google")
    return { Authorization: `Bearer ${token}` }
  }

  /**
   * Cari atau buat folder. Hasilnya di-cache (termasuk yang masih dalam proses)
   * agar upload bersamaan tidak membuat folder ganda dengan nama sama.
   */
  private folderId(name: string, parentId: string): Promise<string> {
    const key = `${parentId}/${name}`
    const cached = this.folderCache.get(key)
    if (cached && cached.expires > Date.now()) return cached.id

    const id = this.findOrCreateFolder(name, parentId)
    this.folderCache.set(key, { id, expires: Date.now() + FOLDER_CACHE_TTL_MS })
    id.catch(() => this.folderCache.delete(key))
    return id
  }

  private async findOrCreateFolder(name: string, parentId: string): Promise<string> {
    const headers = await this.authHeader()
    const search = new URL(`${DRIVE_API}/files`)
    search.searchParams.set(
      "q",
      `name='${escapeDriveQuery(name)}' and mimeType='${FOLDER_MIME}' and '${escapeDriveQuery(parentId)}' in parents and trashed=false`
    )
    search.searchParams.set("fields", "files(id,name)")
    search.searchParams.set("supportsAllDrives", "true")
    search.searchParams.set("includeItemsFromAllDrives", "true")

    const searchRes = await fetch(search, { headers })
    if (!searchRes.ok) throw new Error(`Gagal mencari folder '${name}': ${await searchRes.text()}`)
    const found = (await searchRes.json()) as { files?: { id: string }[] }
    if (found.files && found.files.length > 0) return found.files[0].id

    const createRes = await fetch(`${DRIVE_API}/files?supportsAllDrives=true&fields=id`, {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ name, mimeType: FOLDER_MIME, parents: [parentId] })
    })
    if (!createRes.ok) throw new Error(`Gagal membuat folder '${name}': ${await createRes.text()}`)
    return ((await createRes.json()) as { id: string }).id
  }

  async uploadFile(params: { bytes: Buffer; filename: string; mimeType: string; folderPath: string[] }) {
    let parentId = this.rootFolderId
    for (const name of params.folderPath) {
      parentId = await this.folderId(name, parentId)
    }

    const headers = await this.authHeader()
    const boundary = `pantau_pegawai_${Date.now().toString(36)}`
    const metadata = JSON.stringify({ name: params.filename, parents: [parentId] })
    const head = Buffer.from(
      [
        `--${boundary}`,
        "Content-Type: application/json; charset=UTF-8",
        "",
        metadata,
        `--${boundary}`,
        `Content-Type: ${params.mimeType}`,
        "",
        ""
      ].join("\r\n")
    )
    const tail = Buffer.from(`\r\n--${boundary}--`)

    const uploadRes = await fetch(`${DRIVE_UPLOAD_API}/files?uploadType=multipart&fields=id&supportsAllDrives=true`, {
      method: "POST",
      headers: { ...headers, "Content-Type": `multipart/related; boundary=${boundary}` },
      body: Buffer.concat([head, params.bytes, tail])
    })
    if (!uploadRes.ok) throw new Error(`Upload ke Drive gagal: ${await uploadRes.text()}`)
    const fileId = ((await uploadRes.json()) as { id: string }).id

    // Sama seperti sebelumnya: siapa pun yang punya link bisa melihat foto.
    const permRes = await fetch(`${DRIVE_API}/files/${fileId}/permissions?supportsAllDrives=true`, {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "reader", type: "anyone" })
    })
    if (!permRes.ok) console.warn(`Gagal set permission file ${fileId}: ${await permRes.text()}`)

    return fileId
  }

  async getImage(fileId: string): Promise<DriveImage | null> {
    const headers = await this.authHeader()
    const res = await fetch(`${DRIVE_API}/files/${encodeURIComponent(fileId)}?alt=media&supportsAllDrives=true`, {
      headers
    })
    if (res.status === 404 || res.status === 403) {
      await res.body?.cancel()
      return null
    }
    if (!res.ok || !res.body) throw new Error(`Drive error: ${res.status}`)

    const contentType = res.headers.get("content-type") ?? "application/octet-stream"
    if (!contentType.startsWith("image/")) {
      await res.body.cancel()
      return null
    }
    return {
      stream: Readable.fromWeb(res.body as import("node:stream/web").ReadableStream),
      contentType,
      contentLength: res.headers.get("content-length")
    }
  }
}
