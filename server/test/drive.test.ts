import { afterEach, describe, expect, it, vi } from "vitest"

import { extractAuthCode } from "../scripts/google-oauth-login.js"
import { googleOAuthFromEnv } from "../src/config.js"
import { GoogleDriveService, type TokenSource } from "../src/drive.js"

const token = (value: string): TokenSource => ({ getAccessToken: async () => ({ token: value }) })

/** Stub `fetch`: mencatat header Authorization tiap panggilan dan menjawab berurutan. */
function stubFetch(responses: Response[]) {
  const calls: { url: string; method: string; authorization: string | null }[] = []
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: string | URL, init?: RequestInit) => {
      const headers = new Headers(init?.headers)
      calls.push({ url: String(input), method: init?.method ?? "GET", authorization: headers.get("authorization") })
      const next = responses.shift()
      if (!next) throw new Error(`fetch tak terduga: ${String(input)}`)
      return next
    })
  )
  return calls
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("GoogleDriveService", () => {
  const drive = () => new GoogleDriveService({ read: token("baca"), write: token("tulis") }, "ROOT")

  it("upload (folder, file, izin) memakai token akun penulis", async () => {
    const calls = stubFetch([
      json({ files: [{ id: "folderBudi" }] }), // cari folder pegawai: sudah ada
      json({ files: [] }), // cari folder tanggal: belum ada
      json({ id: "folderTanggal" }), // buat folder tanggal
      json({ id: "file123" }), // upload
      json({ id: "perm" }) // izin "anyone with link"
    ])

    const id = await drive().uploadFile({
      bytes: Buffer.from("jpeg"),
      filename: "foto.jpg",
      mimeType: "image/jpeg",
      folderPath: ["Budi Santoso", "2026-10-11"]
    })

    expect(id).toBe("file123")
    expect(calls).toHaveLength(5)
    expect(calls.every((c) => c.authorization === "Bearer tulis")).toBe(true)
    expect(calls[3].url).toContain("/upload/drive/v3/files")
  })

  it("membaca gambar memakai token service account", async () => {
    const calls = stubFetch([new Response("isi", { headers: { "content-type": "image/jpeg" } })])

    const image = await drive().getImage("file123")

    expect(image?.contentType).toBe("image/jpeg")
    expect(calls[0].authorization).toBe("Bearer baca")
  })

  it("penolakan Drive saat upload dilempar sebagai error berisi detailnya", async () => {
    stubFetch([
      json({ files: [{ id: "folderBudi" }] }),
      json({ files: [{ id: "folderTanggal" }] }),
      json({ error: { code: 403, errors: [{ reason: "storageQuotaExceeded" }] } }, 403)
    ])

    await expect(
      drive().uploadFile({ bytes: Buffer.from("x"), filename: "a.jpg", mimeType: "image/jpeg", folderPath: ["Budi", "2026-10-11"] })
    ).rejects.toThrow(/storageQuotaExceeded/)
  })
})

describe("googleOAuthFromEnv", () => {
  it("dipakai hanya bila ketiga variabel terisi", () => {
    expect(
      googleOAuthFromEnv({
        GOOGLE_OAUTH_CLIENT_ID: " id ",
        GOOGLE_OAUTH_CLIENT_SECRET: "rahasia",
        GOOGLE_OAUTH_REFRESH_TOKEN: "1//token"
      })
    ).toEqual({ clientId: "id", clientSecret: "rahasia", refreshToken: "1//token" })
    expect(googleOAuthFromEnv({})).toBeNull()
  })

  it("terisi sebagian → diabaikan dengan peringatan", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {})
    expect(googleOAuthFromEnv({ GOOGLE_OAUTH_CLIENT_ID: "id", GOOGLE_OAUTH_CLIENT_SECRET: "rahasia" })).toBeNull()
    expect(warn).toHaveBeenCalledOnce()
    warn.mockRestore()
  })
})

describe("extractAuthCode", () => {
  it("menerima URL redirect lengkap atau kode saja", () => {
    expect(extractAuthCode("http://localhost:8765/?code=4%2F0AbCd&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive")).toBe(
      "4/0AbCd"
    )
    expect(extractAuthCode("  4/0AbCd  ")).toBe("4/0AbCd")
    expect(extractAuthCode("4%2F0AbCd")).toBe("4/0AbCd")
  })

  it("menolak input kosong, URL tanpa kode, dan izin yang ditolak", () => {
    expect(() => extractAuthCode("  ")).toThrow(/kosong/)
    expect(() => extractAuthCode("http://localhost:8765/")).toThrow(/code/)
    expect(() => extractAuthCode("http://localhost:8765/?error=access_denied")).toThrow(/access_denied/)
  })
})
