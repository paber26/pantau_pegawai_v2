import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { bearer, seedUsers, setup, teardown, type TestEnv } from "./helpers.js"

let env: TestEnv
let s: Awaited<ReturnType<typeof seedUsers>>

beforeAll(async () => {
  env = await setup()
  s = await seedUsers(env)
})
afterAll(() => teardown(env))

async function create(token: string, payload: Record<string, unknown>) {
  return env.app.inject({ method: "POST", url: "/api/dokumentasi", headers: bearer(token), payload })
}

describe("dokumentasi", () => {
  let budiDocId: string

  it("membuat dokumentasi: user_id & pegawai_nama dari sesi, tanggal tetap yyyy-MM-dd, bentuk join users", async () => {
    const res = await create(s.budi, {
      proyek: "Sakernas Tahun 2026",
      tanggal_kegiatan: "2026-05-04",
      image_url: "https://api.contoh.go.id/api/images?id=abcdefghijk",
      link: "https://api.contoh.go.id/api/images?id=abcdefghijk",
      catatan: "Pencacahan",
      // Diabaikan: tidak bisa membuat dokumentasi atas nama orang lain.
      user_id: s.sitiId,
      pegawai_nama: "Siti Aminah"
    })
    expect(res.statusCode).toBe(200)
    const doc = res.json()
    budiDocId = doc.id
    expect(doc).toMatchObject({
      user_id: s.budiId,
      pegawai_nama: "Budi Santoso",
      proyek: "Sakernas Tahun 2026",
      tanggal_kegiatan: "2026-05-04",
      catatan: "Pencacahan",
      users: { nama: "Budi Santoso", jabatan: "Statistisi", unit_kerja: null }
    })
    expect(Number.isNaN(Date.parse(doc.created_at))).toBe(false)
  })

  it("tanggal_kegiatan wajib & harus valid", async () => {
    expect((await create(s.budi, { proyek: "X" })).statusCode).toBe(400)
    expect((await create(s.budi, { proyek: "X", tanggal_kegiatan: "04/05/2026" })).statusCode).toBe(400)
    expect((await create(s.budi, { proyek: "X", tanggal_kegiatan: "2026-13-45" })).statusCode).toBe(400)
  })

  it("hanya pemilik yang bisa mengubah; admin pun tidak (sama seperti RLS lama)", async () => {
    const payload = { proyek: "Sakernas (revisi)", tanggal_kegiatan: "2026-05-05", image_url: null, catatan: null }
    for (const token of [s.siti, s.admin]) {
      const res = await env.app.inject({ method: "PATCH", url: `/api/dokumentasi/${budiDocId}`, headers: bearer(token), payload })
      expect(res.statusCode).toBe(403)
    }
    const res = await env.app.inject({ method: "PATCH", url: `/api/dokumentasi/${budiDocId}`, headers: bearer(s.budi), payload })
    expect(res.statusCode).toBe(200)
    expect(res.json()).toMatchObject({ proyek: "Sakernas (revisi)", tanggal_kegiatan: "2026-05-05", pegawai_nama: "Budi Santoso" })
  })

  it("pegawai lain tidak bisa menghapus; admin bisa", async () => {
    const del = (token: string) =>
      env.app.inject({ method: "DELETE", url: `/api/dokumentasi/${budiDocId}`, headers: bearer(token) })
    expect((await del(s.siti)).statusCode).toBe(403)
    expect((await del(s.admin)).statusCode).toBe(200)
    expect((await del(s.admin)).statusCode).toBe(404)
  })

  it("mengembalikan semua baris (> 1000) dengan filter dan urutan yang benar", async () => {
    await env.db.query(
      `INSERT INTO dokumentasi (user_id, pegawai_nama, proyek, tanggal_kegiatan, created_at)
       SELECT $1, 'Siti Aminah', 'Proyek ' || g, DATE '2025-01-01' + (g % 365), NOW() - g * interval '1 minute'
         FROM generate_series(1, 1500) g`,
      [s.sitiId]
    )
    await create(s.budi, { proyek: "Proyek Budi", tanggal_kegiatan: "2026-01-10" })

    const all = (await env.app.inject({ url: "/api/dokumentasi", headers: bearer(s.budi) })).json()
    expect(all).toHaveLength(1501)
    expect(all[0].tanggal_kegiatan).toBe("2026-01-10")
    const dates = all.map((d: { tanggal_kegiatan: string }) => d.tanggal_kegiatan)
    expect([...dates].sort().reverse()).toEqual(dates)

    const year = (await env.app.inject({ url: "/api/dokumentasi?year=2025", headers: bearer(s.admin) })).json()
    expect(year).toHaveLength(1500)

    const range = (
      await env.app.inject({ url: "/api/dokumentasi?from=2025-01-01&to=2025-01-31", headers: bearer(s.admin) })
    ).json()
    expect(range.every((d: { tanggal_kegiatan: string }) => d.tanggal_kegiatan.startsWith("2025-01"))).toBe(true)
    expect(range.length).toBeGreaterThan(0)

    // Riwayat per user: urut waktu penambahan terbaru.
    const mine = (await env.app.inject({ url: `/api/dokumentasi?user_id=${s.sitiId}`, headers: bearer(s.siti) })).json()
    expect(mine).toHaveLength(1500)
    expect(mine[0].proyek).toBe("Proyek 1")
  })

  it("butuh login", async () => {
    expect((await env.app.inject({ url: "/api/dokumentasi" })).statusCode).toBe(401)
  })
})
