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

describe("hapus sementara (soft delete)", () => {
  const ids = async (token: string, query = "") =>
    (await env.app.inject({ url: `/api/dokumentasi${query}`, headers: bearer(token) }))
      .json()
      .map((d: { id: string }) => d.id)

  it("pegawai menghapus miliknya: hilang dari daftar, admin bisa melihat dan mengembalikan", async () => {
    const doc = (await create(s.budi, { proyek: "Akan dihapus", tanggal_kegiatan: "2026-10-11" })).json()

    // Aplikasi lama mengirim Content-Type JSON tanpa body; tetap diterima.
    const del = await env.app.inject({
      method: "DELETE",
      url: `/api/dokumentasi/${doc.id}`,
      headers: { ...bearer(s.budi), "content-type": "application/json" }
    })
    expect(del.statusCode).toBe(200)

    expect(await ids(s.budi)).not.toContain(doc.id)
    expect(await ids(s.siti)).not.toContain(doc.id)
    expect(await ids(s.admin)).not.toContain(doc.id)
    expect(await ids(s.budi, `?user_id=${s.budiId}`)).not.toContain(doc.id)

    // Daftar yang dihapus: khusus admin, lengkap dengan siapa yang menghapus.
    expect((await env.app.inject({ url: "/api/dokumentasi?deleted=true", headers: bearer(s.budi) })).statusCode).toBe(403)
    const trash = (await env.app.inject({ url: "/api/dokumentasi?deleted=true", headers: bearer(s.admin) })).json()
    expect(trash.every((d: { deleted_at: string | null }) => d.deleted_at)).toBe(true)
    expect(trash.find((d: { id: string }) => d.id === doc.id)).toMatchObject({
      proyek: "Akan dihapus",
      deleted_by: s.budiId,
      deleted_by_nama: "Budi Santoso",
      users: { nama: "Budi Santoso" }
    })

    // Yang sudah dihapus tidak bisa diubah atau dihapus lagi.
    const patch = await env.app.inject({
      method: "PATCH",
      url: `/api/dokumentasi/${doc.id}`,
      headers: bearer(s.budi),
      payload: { proyek: "Ubah", tanggal_kegiatan: "2026-10-11" }
    })
    expect(patch.statusCode).toBe(404)
    expect((await env.app.inject({ method: "DELETE", url: `/api/dokumentasi/${doc.id}`, headers: bearer(s.budi) })).statusCode).toBe(404)

    // Hanya admin yang bisa mengembalikan.
    const restore = (token: string) =>
      env.app.inject({ method: "POST", url: `/api/dokumentasi/${doc.id}/restore`, headers: bearer(token) })
    expect((await restore(s.budi)).statusCode).toBe(403)
    const restored = await restore(s.admin)
    expect(restored.statusCode).toBe(200)
    expect(restored.json()).toMatchObject({ id: doc.id, deleted_at: null, deleted_by: null, deleted_by_nama: null })
    expect(await ids(s.budi)).toContain(doc.id)
    expect(await ids(s.admin, "?deleted=true")).not.toContain(doc.id)
    expect((await restore(s.admin)).statusCode).toBe(404)
  })

  it("admin menghapus dokumentasi pegawai: tercatat sebagai penghapus", async () => {
    const doc = (await create(s.siti, { proyek: "Dihapus admin", tanggal_kegiatan: "2026-10-11" })).json()
    expect((await env.app.inject({ method: "DELETE", url: `/api/dokumentasi/${doc.id}`, headers: bearer(s.admin) })).statusCode).toBe(200)
    const trash = (await env.app.inject({ url: "/api/dokumentasi?deleted=true", headers: bearer(s.admin) })).json()
    expect(trash[0]).toMatchObject({ id: doc.id, deleted_by_nama: "Admin Sistem", pegawai_nama: "Siti Aminah" })
  })
})
