import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { buildApp } from "../src/app.js"
import { normalizeDate } from "../src/dates.js"
import { escapeDriveQuery } from "../src/drive.js"
import {
  bearer,
  FakeDrive,
  multipartBody,
  PUBLIC_API_URL,
  seedUsers,
  setup,
  teardown,
  testConfig,
  type TestEnv
} from "./helpers.js"

let env: TestEnv
let s: Awaited<ReturnType<typeof seedUsers>>

beforeAll(async () => {
  env = await setup()
  s = await seedUsers(env)
})
afterAll(() => teardown(env))

describe("dashboard", () => {
  it("hanya admin", async () => {
    expect((await env.app.inject({ url: "/api/dashboard/stats", headers: bearer(s.budi) })).statusCode).toBe(403)
  })

  it("menghitung dengan COUNT (> 1000) dan 'belum upload' dari dokumentasi hari ini (WITA)", async () => {
    const { rows } = await env.db.query("SELECT (NOW() AT TIME ZONE 'Asia/Makassar')::date AS today")
    const today: string = rows[0].today
    await env.db.query(
      `INSERT INTO dokumentasi (user_id, proyek, tanggal_kegiatan)
       SELECT $1, 'Lama', DATE '2025-01-01' FROM generate_series(1, 1200)`,
      [s.sitiId]
    )
    await env.db.query(`INSERT INTO dokumentasi (user_id, proyek, tanggal_kegiatan) VALUES ($1, 'Hari ini', $2)`, [
      s.budiId,
      today
    ])

    const stats = (await env.app.inject({ url: "/api/dashboard/stats", headers: bearer(s.admin) })).json()
    expect(stats).toEqual({
      total_pegawai: 2,
      jumlah_proyek: 0,
      total_dokumentasi: 1201,
      pegawai_belum_upload: 1, // Siti belum upload hari ini
      tanggal: today
    })
  })

  it("dokumentasi yang dihapus tidak dihitung", async () => {
    await env.db.query("UPDATE dokumentasi SET deleted_at = NOW() WHERE proyek = 'Hari ini'")
    const stats = (await env.app.inject({ url: "/api/dashboard/stats", headers: bearer(s.admin) })).json()
    expect(stats).toMatchObject({ total_dokumentasi: 1200, pegawai_belum_upload: 2 })
  })
})

describe("upload & gambar", () => {
  it("upload ke Drive memakai nama pegawai dari akun, URL gambar memakai PUBLIC_API_URL", async () => {
    const form = new FormData()
    form.set("pegawai_nama", "Nama Palsu")
    form.set("tanggal", "2026-05-04")
    form.set("filename", "foto_20260504_101010.jpg")
    form.set("file", new Blob([Buffer.from("isi-gambar-jpeg")], { type: "image/jpeg" }), "foto.jpg")
    const { payload, headers } = await multipartBody(form)

    const res = await env.app.inject({
      method: "POST",
      url: "/api/uploads",
      headers: { ...headers, ...bearer(s.budi) },
      payload
    })
    expect(res.statusCode).toBe(200)
    const { image_url, file_id } = res.json()
    expect(image_url).toBe(`${PUBLIC_API_URL}/api/images?id=${file_id}`)
    expect(env.drive.files.get(file_id)).toMatchObject({
      folderPath: ["Budi Santoso", "2026-05-04"],
      filename: "foto_20260504_101010.jpg",
      mimeType: "image/jpeg"
    })

    // Gambar bisa diambil tanpa login, dengan CORS terbuka & cache panjang.
    const img = await env.app.inject({
      url: `/api/images?id=${file_id}`,
      headers: { origin: "https://situs-lain.example" }
    })
    expect(img.statusCode).toBe(200)
    expect(img.headers["content-type"]).toBe("image/jpeg")
    expect(img.headers["access-control-allow-origin"]).toBe("*")
    expect(img.headers["cache-control"]).toContain("max-age")
    expect(img.body).toBe("isi-gambar-jpeg")
  })

  it("upload butuh login, file, dan tanggal yang valid", async () => {
    const form = new FormData()
    form.set("tanggal", "kemarin")
    form.set("file", new Blob([Buffer.from("x")], { type: "image/jpeg" }), "foto.jpg")
    const { payload, headers } = await multipartBody(form)
    expect((await env.app.inject({ method: "POST", url: "/api/uploads", headers, payload })).statusCode).toBe(401)
    const bad = await env.app.inject({ method: "POST", url: "/api/uploads", headers: { ...headers, ...bearer(s.budi) }, payload })
    expect(bad.statusCode).toBe(400)
  })

  it("Drive menolak upload → 502 dengan pesan yang jelas, detail tidak bocor", async () => {
    env.drive.uploadError = new Error("Upload ke Drive gagal: 403 storageQuotaExceeded")
    const form = new FormData()
    form.set("tanggal", "2026-10-11")
    form.set("file", new Blob([Buffer.from("x")], { type: "image/jpeg" }), "foto.jpg")
    const { payload, headers } = await multipartBody(form)
    try {
      const res = await env.app.inject({ method: "POST", url: "/api/uploads", headers: { ...headers, ...bearer(s.budi) }, payload })
      expect(res.statusCode).toBe(502)
      expect(res.json().error).toBe("Upload foto ke Google Drive gagal. Coba lagi atau hubungi admin.")
    } finally {
      env.drive.uploadError = null
    }
  })

  it("id gambar divalidasi; yang tidak ada → 404", async () => {
    expect((await env.app.inject({ url: "/api/images?id=../../etc" })).statusCode).toBe(400)
    expect((await env.app.inject({ url: "/api/images?id=tidakAdaFileIni123" })).statusCode).toBe(404)
    expect((await env.app.inject({ url: "/api/images/thumb?id=tidakAdaFileIni123" })).statusCode).toBe(404)
    expect((await env.app.inject({ url: "/api/images/thumb?id=../../etc" })).statusCode).toBe(400)
  })

  it("/api/images/thumb → thumbnail Drive (cache lama); belum ada → foto asli dengan cache pendek", async () => {
    const drive = new FakeDrive()
    const app = await buildApp({ config: testConfig(), db: env.db, drive })
    const id = await drive.uploadFile({
      bytes: Buffer.from("foto-asli"),
      filename: "foto.jpg",
      mimeType: "image/jpeg",
      folderPath: ["Budi Santoso", "2026-10-13"]
    })
    try {
      const thumb = await app.inject({ url: `/api/images/thumb?id=${id}` })
      expect(thumb.statusCode).toBe(200)
      expect(thumb.body).toBe("thumb320:foto-asli")
      expect(thumb.headers["cache-control"]).toContain("immutable")

      // Foto asli tetap tersedia tanpa size.
      expect((await app.inject({ url: `/api/images?id=${id}` })).body).toBe("foto-asli")

      drive.thumbnailsReady = false
      const fallback = await app.inject({ url: `/api/images/thumb?id=${id}` })
      expect(fallback.statusCode).toBe(200)
      expect(fallback.body).toBe("foto-asli")
      expect(fallback.headers["cache-control"]).toBe("public, max-age=600")

      drive.getThumbnail = async () => {
        throw new Error("lh3 429")
      }
      const error = await app.inject({ url: `/api/images/thumb?id=${id}` })
      expect(error.statusCode).toBe(200)
      expect(error.body).toBe("foto-asli")
    } finally {
      await app.close()
    }
  })

  it("tanpa kredensial Drive → 503 yang jelas", async () => {
    const app = await buildApp({ config: testConfig(), db: env.db, drive: null })
    const res = await app.inject({ url: "/api/images?id=abcdefghijkl" })
    expect(res.statusCode).toBe(503)
    await app.close()
  })

  it("escape nama folder Drive (mis. Ma'ruf)", () => {
    expect(escapeDriveQuery("Ma'ruf")).toBe("Ma\\'ruf")
    expect(escapeDriveQuery("a\\b")).toBe("a\\\\b")
  })
})

describe("import dari spreadsheet", () => {
  it("hanya admin, hanya tabel yang didukung", async () => {
    const body = { targetTable: "kegiatan", rows: [{ judul: "A", deadline: "2026-01-01" }] }
    expect((await env.app.inject({ method: "POST", url: "/api/import", headers: bearer(s.budi), payload: body })).statusCode).toBe(403)
    const users = await env.app.inject({
      method: "POST",
      url: "/api/import",
      headers: bearer(s.admin),
      payload: { targetTable: "users", rows: [{ nama: "X" }] }
    })
    expect(users.statusCode).toBe(400)
  })

  it("baris rusak tidak menggagalkan baris lain; tanggal dd/MM/yyyy dinormalisasi", async () => {
    const res = await env.app.inject({
      method: "POST",
      url: "/api/import",
      headers: bearer(s.admin),
      payload: {
        targetTable: "dokumentasi",
        rows: [
          { user_id: s.budiId, proyek: "Import 1", tanggal_kegiatan: "25/12/2025", catatan: "ok" },
          { user_id: "bukan-uuid", proyek: "Import 2", tanggal_kegiatan: "2025-12-25" },
          { user_id: s.sitiId, proyek: "Import 3", tanggal_kegiatan: "2025-12-26", kolom_aneh: "x" },
          { user_id: s.sitiId, proyek: "Import 4", tanggal_kegiatan: "12/31/2025", link: "" }
        ]
      }
    })
    expect(res.statusCode).toBe(200)
    const body = res.json()
    expect(body).toMatchObject({ success: true, imported: 2, failed: 2 })
    expect(body.errors.map((e: { rowIndex: number }) => e.rowIndex)).toEqual([1, 2])

    const { rows } = await env.db.query(
      "SELECT proyek, tanggal_kegiatan, pegawai_nama, link FROM dokumentasi WHERE proyek LIKE 'Import%' ORDER BY proyek"
    )
    expect(rows).toEqual([
      { proyek: "Import 1", tanggal_kegiatan: "2025-12-25", pegawai_nama: "Budi Santoso", link: null },
      { proyek: "Import 4", tanggal_kegiatan: "2025-12-31", pegawai_nama: "Siti Aminah", link: null }
    ])
  })

  it("normalizeDate", () => {
    expect(normalizeDate("2026-05-04")).toBe("2026-05-04")
    expect(normalizeDate("2026-05-04T10:00:00Z")).toBe("2026-05-04")
    expect(normalizeDate("4/5/2026")).toBe("2026-05-04")
    expect(normalizeDate("12/31/2025")).toBe("2025-12-31")
    expect(normalizeDate("31/02/2026")).toBeNull()
    expect(normalizeDate("besok")).toBeNull()
  })
})
