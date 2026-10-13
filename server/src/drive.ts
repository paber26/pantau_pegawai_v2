/**
 * Akses Google Drive (pengganti Edge Function `upload-to-drive` dan `image-proxy`).
 *
 * - Membaca gambar memakai service account (GOOGLE_SERVICE_ACCOUNT_FILE).
 * - Menulis (folder, upload, izin) memakai OAuth akun Gmail pemilik folder bila
 *   GOOGLE_OAUTH_* diisi. Service account tidak punya kuota penyimpanan, jadi
 *   Google menolak file baru miliknya di My Drive akun Gmail biasa
 *   (403 storageQuotaExceeded). Tanpa OAuth, penulisan memakai service account
 *   (berhasil bila folder root ada di Shared Drive).
 *
 * Token akses di-cache oleh google-auth-library sampai hampir kedaluwarsa.
 */
import { readFileSync } from "node:fs"
import { Readable } from "node:stream"

import { JWT, OAuth2Client } from "google-auth-library"

import type { GoogleOAuthConfig } from "./config.js"

const DRIVE_API = "https://www.googleapis.com/drive/v3"
const DRIVE_UPLOAD_API = "https://www.googleapis.com/upload/drive/v3"
const FOLDER_MIME = "application/vnd.google-apps.folder"
const FOLDER_CACHE_TTL_MS = 60 * 60 * 1000
/** Batas upload multipart menurut Drive; file lebih besar memakai upload resumable. */
const MULTIPART_MAX_BYTES = 5 * 1024 * 1024

export interface DriveImage {
  stream: Readable
  contentType: string
  contentLength: string | null
}

export interface UploadParams {
  bytes: Buffer
  filename: string
  mimeType: string
  folderPath: string[]
  /** Beri izin "siapa pun yang punya link bisa melihat". Default `true` (foto dokumentasi). */
  shareWithLink?: boolean
}

export interface DriveService {
  /** Upload file ke ROOT/{folderPath...}/filename. Mengembalikan file ID. */
  uploadFile(params: UploadParams): Promise<string>
  /** Nama file (bukan folder) di ROOT/{folderPath...}. Folder yang belum ada dibuat. */
  listFileNames(folderPath: string[]): Promise<string[]>
  /** Ambil isi gambar. `null` bila file tidak ada atau bukan gambar. */
  getImage(fileId: string): Promise<DriveImage | null>
}

/** Escape nilai untuk query Drive (`name='...'`). Nama seperti "Ma'ruf" tetap aman. */
export function escapeDriveQuery(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/'/g, "\\'")
}

/** Sumber access token Google: `JWT` (service account) atau `OAuth2Client`. */
export interface TokenSource {
  getAccessToken(): Promise<{ token?: string | null }>
}

/**
 * Membuat `GoogleDriveService` dari konfigurasi: service account untuk membaca,
 * dan OAuth pemilik folder (bila ada) untuk menulis.
 */
export function createGoogleDriveService(options: {
  serviceAccountFile: string
  rootFolderId: string
  oauth: GoogleOAuthConfig | null
}): GoogleDriveService {
  const credentials = JSON.parse(readFileSync(options.serviceAccountFile, "utf8")) as {
    client_email: string
    private_key: string
  }
  const serviceAccount = new JWT({
    email: credentials.client_email,
    key: credentials.private_key,
    scopes: ["https://www.googleapis.com/auth/drive"]
  })

  let writer: TokenSource = serviceAccount
  if (options.oauth) {
    const client = new OAuth2Client({ clientId: options.oauth.clientId, clientSecret: options.oauth.clientSecret })
    client.setCredentials({ refresh_token: options.oauth.refreshToken })
    writer = client
  }
  return new GoogleDriveService({ read: serviceAccount, write: writer }, options.rootFolderId)
}

export class GoogleDriveService implements DriveService {
  private readonly folderCache = new Map<string, { id: Promise<string>; expires: number }>()

  constructor(
    private readonly auth: { read: TokenSource; write: TokenSource },
    private readonly rootFolderId: string
  ) {}

  private async authHeader(source: TokenSource): Promise<Record<string, string>> {
    const { token } = await source.getAccessToken()
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
    const headers = await this.authHeader(this.auth.write)
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

  private async folderPathId(folderPath: string[]): Promise<string> {
    let parentId = this.rootFolderId
    for (const name of folderPath) {
      parentId = await this.folderId(name, parentId)
    }
    return parentId
  }

  async uploadFile(params: UploadParams) {
    const parentId = await this.folderPathId(params.folderPath)
    const headers = await this.authHeader(this.auth.write)
    const metadata = JSON.stringify({ name: params.filename, parents: [parentId] })
    const fileId =
      params.bytes.length > MULTIPART_MAX_BYTES
        ? await this.uploadResumable(headers, metadata, params)
        : await this.uploadMultipart(headers, metadata, params)

    if (params.shareWithLink === false) return fileId

    // Sama seperti sebelumnya: siapa pun yang punya link bisa melihat foto.
    const permRes = await fetch(`${DRIVE_API}/files/${fileId}/permissions?supportsAllDrives=true`, {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "reader", type: "anyone" })
    })
    if (!permRes.ok) console.warn(`Gagal set permission file ${fileId}: ${await permRes.text()}`)

    return fileId
  }

  private async uploadMultipart(headers: Record<string, string>, metadata: string, params: UploadParams) {
    const boundary = `pantau_pegawai_${Date.now().toString(36)}`
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
    return ((await uploadRes.json()) as { id: string }).id
  }

  /** Upload resumable dalam satu PUT: sesi dibuka dengan metadata, lalu isi file dikirim ke URL sesi. */
  private async uploadResumable(headers: Record<string, string>, metadata: string, params: UploadParams) {
    const startRes = await fetch(`${DRIVE_UPLOAD_API}/files?uploadType=resumable&fields=id&supportsAllDrives=true`, {
      method: "POST",
      headers: {
        ...headers,
        "Content-Type": "application/json; charset=UTF-8",
        "X-Upload-Content-Type": params.mimeType,
        "X-Upload-Content-Length": String(params.bytes.length)
      },
      body: metadata
    })
    if (!startRes.ok) throw new Error(`Upload ke Drive gagal: ${await startRes.text()}`)
    await startRes.body?.cancel()
    const sessionUrl = startRes.headers.get("location")
    if (!sessionUrl) throw new Error("Upload ke Drive gagal: Drive tidak memberi URL sesi upload")

    const uploadRes = await fetch(sessionUrl, {
      method: "PUT",
      headers: { ...headers, "Content-Type": params.mimeType },
      body: new Uint8Array(params.bytes)
    })
    if (!uploadRes.ok) throw new Error(`Upload ke Drive gagal: ${await uploadRes.text()}`)
    return ((await uploadRes.json()) as { id: string }).id
  }

  async listFileNames(folderPath: string[]): Promise<string[]> {
    const folderId = await this.folderPathId(folderPath)
    const headers = await this.authHeader(this.auth.write)
    const names: string[] = []
    let pageToken: string | undefined
    do {
      const url = new URL(`${DRIVE_API}/files`)
      url.searchParams.set(
        "q",
        `'${escapeDriveQuery(folderId)}' in parents and mimeType!='${FOLDER_MIME}' and trashed=false`
      )
      url.searchParams.set("fields", "nextPageToken,files(name)")
      url.searchParams.set("pageSize", "1000")
      url.searchParams.set("supportsAllDrives", "true")
      url.searchParams.set("includeItemsFromAllDrives", "true")
      if (pageToken) url.searchParams.set("pageToken", pageToken)

      const res = await fetch(url, { headers })
      if (!res.ok) throw new Error(`Gagal membaca isi folder '${folderPath.join("/")}': ${await res.text()}`)
      const page = (await res.json()) as { nextPageToken?: string; files?: { name: string }[] }
      names.push(...(page.files ?? []).map((f) => f.name))
      pageToken = page.nextPageToken
    } while (pageToken)
    return names
  }

  async getImage(fileId: string): Promise<DriveImage | null> {
    const headers = await this.authHeader(this.auth.read)
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
