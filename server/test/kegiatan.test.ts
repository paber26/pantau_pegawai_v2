import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { bearer, seedUsers, setup, teardown, type TestEnv } from "./helpers.js"

let env: TestEnv
let s: Awaited<ReturnType<typeof seedUsers>>

beforeAll(async () => {
  env = await setup()
  s = await seedUsers(env)
})
afterAll(() => teardown(env))

describe("kegiatan", () => {
  let kegiatanId: string

  it("hanya admin yang bisa menambah; deadline yyyy-MM-dd", async () => {
    const payload = { judul: "Sakernas", deskripsi: "Survei angkatan kerja", deadline: "2026-08-31" }
    const denied = await env.app.inject({ method: "POST", url: "/api/kegiatan", headers: bearer(s.budi), payload })
    expect(denied.statusCode).toBe(403)

    const res = await env.app.inject({ method: "POST", url: "/api/kegiatan", headers: bearer(s.admin), payload })
    expect(res.statusCode).toBe(200)
    expect(res.json()).toMatchObject(payload)
    kegiatanId = res.json().id
  })

  it("semua yang login bisa membaca, urut deadline", async () => {
    await env.app.inject({
      method: "POST",
      url: "/api/kegiatan",
      headers: bearer(s.admin),
      payload: { judul: "Podes", deadline: "2026-06-30" }
    })
    const list = (await env.app.inject({ url: "/api/kegiatan", headers: bearer(s.budi) })).json()
    expect(list.map((k: { judul: string }) => k.judul)).toEqual(["Podes", "Sakernas"])
    const one = await env.app.inject({ url: `/api/kegiatan/${kegiatanId}`, headers: bearer(s.budi) })
    expect(one.json().judul).toBe("Sakernas")
  })

  it("update & delete oleh admin", async () => {
    const upd = await env.app.inject({
      method: "PATCH",
      url: `/api/kegiatan/${kegiatanId}`,
      headers: bearer(s.admin),
      payload: { judul: "Sakernas Agustus", deskripsi: null, deadline: "2026-09-01" }
    })
    expect(upd.json()).toMatchObject({ judul: "Sakernas Agustus", deskripsi: null, deadline: "2026-09-01" })
    const denied = await env.app.inject({ method: "DELETE", url: `/api/kegiatan/${kegiatanId}`, headers: bearer(s.budi) })
    expect(denied.statusCode).toBe(403)
  })

  it("bulk import melewati judul yang sudah ada", async () => {
    const res = await env.app.inject({
      method: "POST",
      url: "/api/kegiatan/bulk",
      headers: bearer(s.admin),
      payload: { judul_list: ["Podes", "Susenas", "Sakernas Agustus", "Jumat Sehat"], deadline: "2026-12-31" }
    })
    expect(res.json()).toEqual({ inserted: 2, skipped: 2 })
    const list = (await env.app.inject({ url: "/api/kegiatan", headers: bearer(s.admin) })).json()
    expect(list).toHaveLength(4)
  })
})

describe("penugasan", () => {
  let kegiatanId: string

  beforeAll(async () => {
    const { rows } = await env.db.query("SELECT id FROM kegiatan WHERE judul = 'Podes'")
    kegiatanId = rows[0].id
  })

  it("admin menugaskan; duplikat ditolak; pegawai tidak bisa menugaskan", async () => {
    const assign = (token: string, userId: string) =>
      env.app.inject({
        method: "POST",
        url: "/api/penugasan",
        headers: bearer(token),
        payload: { user_id: userId, kegiatan_id: kegiatanId }
      })
    expect((await assign(s.admin, s.budiId)).statusCode).toBe(200)
    expect((await assign(s.admin, s.sitiId)).statusCode).toBe(200)
    expect((await assign(s.admin, s.budiId)).statusCode).toBe(409)
    expect((await assign(s.budi, s.budiId)).statusCode).toBe(403)
  })

  it("bentuk respons users(*) tanpa password; pegawai hanya melihat miliknya", async () => {
    const adminView = (
      await env.app.inject({ url: `/api/penugasan?kegiatan_id=${kegiatanId}`, headers: bearer(s.admin) })
    ).json()
    expect(adminView).toHaveLength(2)
    expect(adminView[0].users).toMatchObject({ id: s.budiId, nama: "Budi Santoso", role: "pegawai" })
    expect(typeof adminView[0].users.created_at).toBe("string")
    expect(JSON.stringify(adminView)).not.toContain("password")

    const budiView = (
      await env.app.inject({ url: `/api/penugasan?kegiatan_id=${kegiatanId}`, headers: bearer(s.budi) })
    ).json()
    expect(budiView).toHaveLength(1)
  })

  it("kegiatan yang ditugaskan (assigned_to)", async () => {
    const mine = await env.app.inject({ url: `/api/kegiatan?assigned_to=${s.budiId}`, headers: bearer(s.budi) })
    expect(mine.json().map((k: { judul: string }) => k.judul)).toEqual(["Podes"])
    const others = await env.app.inject({ url: `/api/kegiatan?assigned_to=${s.sitiId}`, headers: bearer(s.budi) })
    expect(others.statusCode).toBe(403)
  })

  it("admin mencabut penugasan", async () => {
    const res = await env.app.inject({
      method: "DELETE",
      url: `/api/penugasan?user_id=${s.sitiId}&kegiatan_id=${kegiatanId}`,
      headers: bearer(s.admin)
    })
    expect(res.statusCode).toBe(200)
  })
})

describe("laporan", () => {
  let kegiatanId: string
  let laporanId: string

  beforeAll(async () => {
    const { rows } = await env.db.query("SELECT id FROM kegiatan WHERE judul = 'Podes'")
    kegiatanId = rows[0].id
  })

  it("pegawai membuat laporan atas namanya sendiri", async () => {
    const res = await env.app.inject({
      method: "POST",
      url: "/api/laporan",
      headers: bearer(s.budi),
      payload: { kegiatan_id: kegiatanId, image_url: "https://api.contoh.go.id/api/images?id=abcdefghijk", deskripsi: "Selesai" }
    })
    expect(res.statusCode).toBe(200)
    expect(res.json()).toMatchObject({ user_id: s.budiId, users: { nama: "Budi Santoso" }, kegiatan: { judul: "Podes" } })
    laporanId = res.json().id
  })

  it("pegawai hanya melihat laporannya sendiri; admin melihat semua", async () => {
    const siti = (await env.app.inject({ url: "/api/laporan", headers: bearer(s.siti) })).json()
    expect(siti).toHaveLength(0)
    // Pegawai tidak bisa "mengintip" lewat parameter user_id.
    const sneaky = (await env.app.inject({ url: `/api/laporan?user_id=${s.budiId}`, headers: bearer(s.siti) })).json()
    expect(sneaky).toHaveLength(0)
    expect((await env.app.inject({ url: `/api/laporan/${laporanId}`, headers: bearer(s.siti) })).statusCode).toBe(404)

    const admin = (await env.app.inject({ url: `/api/laporan?kegiatan_id=${kegiatanId}`, headers: bearer(s.admin) })).json()
    expect(admin).toHaveLength(1)
    const from = encodeURIComponent(new Date(Date.now() - 3600_000).toISOString())
    const recent = (await env.app.inject({ url: `/api/laporan?from=${from}`, headers: bearer(s.admin) })).json()
    expect(recent).toHaveLength(1)
  })
})
