import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { bearer, login, seedUsers, setup, teardown, type TestEnv } from "./helpers.js"

let env: TestEnv
let s: Awaited<ReturnType<typeof seedUsers>>

beforeAll(async () => {
  env = await setup()
  s = await seedUsers(env)
})
afterAll(() => teardown(env))

describe("daftar pegawai", () => {
  it("bisa dibaca semua user yang login, urut nama, tanpa password_hash", async () => {
    const res = await env.app.inject({ url: "/api/users", headers: bearer(s.budi) })
    expect(res.statusCode).toBe(200)
    const users = res.json()
    expect(users.map((u: { nama: string }) => u.nama)).toEqual(["Admin Sistem", "Budi Santoso", "Siti Aminah"])
    expect(res.body).not.toContain("password_hash")
    expect(res.body).not.toContain("$2a$")
    expect(users[1]).toMatchObject({ id: s.budiId, email: "budi@bps.go.id", jabatan: "Statistisi", role: "pegawai" })
    expect(typeof users[1].created_at).toBe("string")
  })

  it("detail pegawai & 404", async () => {
    const res = await env.app.inject({ url: `/api/users/${s.sitiId}`, headers: bearer(s.budi) })
    expect(res.json().nama).toBe("Siti Aminah")
    const missing = await env.app.inject({
      url: "/api/users/00000000-0000-0000-0000-000000000000",
      headers: bearer(s.budi)
    })
    expect(missing.statusCode).toBe(404)
  })
})

describe("aksi admin", () => {
  it("pegawai tidak bisa mengubah role sendiri jadi admin (celah RLS lama)", async () => {
    const res = await env.app.inject({
      method: "PATCH",
      url: `/api/users/${s.budiId}`,
      headers: bearer(s.budi),
      payload: { nama: "Budi Santoso", role: "admin" }
    })
    expect(res.statusCode).toBe(403)
    const { rows } = await env.db.query("SELECT role FROM users WHERE id = $1", [s.budiId])
    expect(rows[0].role).toBe("pegawai")
  })

  it("pegawai tidak bisa membuat, menghapus, atau reset password user", async () => {
    const create = await env.app.inject({
      method: "POST",
      url: "/api/users",
      headers: bearer(s.budi),
      payload: { nama: "X", email: "x@bps.go.id", password: "123456" }
    })
    const del = await env.app.inject({ method: "DELETE", url: `/api/users/${s.sitiId}`, headers: bearer(s.budi) })
    const reset = await env.app.inject({
      method: "POST",
      url: `/api/users/${s.sitiId}/reset-password`,
      headers: bearer(s.budi),
      payload: { new_password: "123456" }
    })
    expect([create.statusCode, del.statusCode, reset.statusCode]).toEqual([403, 403, 403])
  })

  it("admin membuat pegawai baru yang langsung bisa login", async () => {
    const res = await env.app.inject({
      method: "POST",
      url: "/api/users",
      headers: bearer(s.admin),
      payload: { nama: "Rina", email: "rina@bps.go.id", password: "rinarina", jabatan: null, unit_kerja: "IPDS", role: "pegawai" }
    })
    expect(res.statusCode).toBe(200)
    expect(res.json()).toMatchObject({ success: true, user: { nama: "Rina", unit_kerja: "IPDS", role: "pegawai" } })
    expect(await login(env.app, "rina@bps.go.id", "rinarina")).toBeTruthy()

    const dup = await env.app.inject({
      method: "POST",
      url: "/api/users",
      headers: bearer(s.admin),
      payload: { nama: "Rina 2", email: "RINA@bps.go.id", password: "rinarina" }
    })
    expect(dup.statusCode).toBe(409)
    expect(dup.json().error).toBe("Email sudah terdaftar.")

    const short = await env.app.inject({
      method: "POST",
      url: "/api/users",
      headers: bearer(s.admin),
      payload: { nama: "Rina 3", email: "rina3@bps.go.id", password: "123" }
    })
    expect(short.statusCode).toBe(400)
  })

  it("admin mengubah data pegawai", async () => {
    const res = await env.app.inject({
      method: "PATCH",
      url: `/api/users/${s.sitiId}`,
      headers: bearer(s.admin),
      payload: { nama: "Siti Aminah, S.Si", jabatan: "Kasi", unit_kerja: "", role: "pegawai" }
    })
    expect(res.statusCode).toBe(200)
    expect(res.json()).toMatchObject({ nama: "Siti Aminah, S.Si", jabatan: "Kasi", unit_kerja: null })
  })

  it("reset password memaksa login ulang dengan password baru", async () => {
    const res = await env.app.inject({
      method: "POST",
      url: `/api/users/${s.sitiId}/reset-password`,
      headers: bearer(s.admin),
      payload: { new_password: "baru1234" }
    })
    expect(res.json()).toEqual({ success: true, message: "Password berhasil diubah" })
    expect((await env.app.inject({ url: "/api/auth/me", headers: bearer(s.siti) })).statusCode).toBe(401)
    await expect(login(env.app, "siti@bps.go.id")).rejects.toThrow()
    expect(await login(env.app, "siti@bps.go.id", "baru1234")).toBeTruthy()
  })

  it("admin tidak bisa menghapus diri sendiri; hapus pegawai ikut menghapus datanya", async () => {
    const self = await env.app.inject({ method: "DELETE", url: `/api/users/${s.adminId}`, headers: bearer(s.admin) })
    expect(self.statusCode).toBe(400)

    await env.app.inject({
      method: "POST",
      url: "/api/dokumentasi",
      headers: bearer(s.budi),
      payload: { proyek: "Sakernas", tanggal_kegiatan: "2026-05-04" }
    })
    const res = await env.app.inject({ method: "DELETE", url: `/api/users/${s.budiId}`, headers: bearer(s.admin) })
    expect(res.json()).toEqual({ success: true })
    const { rows } = await env.db.query("SELECT COUNT(*)::int AS n FROM dokumentasi WHERE user_id = $1", [s.budiId])
    expect(rows[0].n).toBe(0)
    expect((await env.app.inject({ url: "/api/auth/me", headers: bearer(s.budi) })).statusCode).toBe(401)
  })
})
