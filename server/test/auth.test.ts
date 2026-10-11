import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { bearer, createUser, login, setup, teardown, type TestEnv } from "./helpers.js"

let env: TestEnv

beforeAll(async () => {
  env = await setup()
  await createUser(env.db, { nama: "Budi Santoso", email: "Budi@BPS.go.id", password: "passwordLama" })
  await createUser(env.db, { nama: "Tanpa Password", email: "kosong@bps.go.id", password: null })
})
afterAll(() => teardown(env))

describe("login", () => {
  it("menerima password lama dengan hash $2a$ dari Supabase, email tidak case-sensitive", async () => {
    const res = await env.app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: { email: " budi@bps.go.id ", password: "passwordLama" }
    })
    expect(res.statusCode).toBe(200)
    const body = res.json()
    expect(body.token).toMatch(/^[A-Za-z0-9_-]{40,}$/)
    expect(body.user).toMatchObject({ nama: "Budi Santoso", email: "Budi@BPS.go.id", role: "pegawai" })
    expect(body.user.password_hash).toBeUndefined()
  })

  it("menolak password salah, email tak dikenal, dan akun tanpa password", async () => {
    for (const payload of [
      { email: "budi@bps.go.id", password: "salah" },
      { email: "tidakada@bps.go.id", password: "passwordLama" },
      { email: "kosong@bps.go.id", password: "" },
      { email: "kosong@bps.go.id", password: "apa saja" }
    ]) {
      const res = await env.app.inject({ method: "POST", url: "/api/auth/login", payload })
      expect([400, 401]).toContain(res.statusCode)
      expect(res.json().error).toBeTruthy()
    }
  })

  it("token disimpan sebagai hash, bukan teks asli", async () => {
    const token = await login(env.app, "budi@bps.go.id", "passwordLama")
    const { rows } = await env.db.query("SELECT token_hash FROM sessions")
    expect(rows.map((r) => r.token_hash)).not.toContain(token)
  })
})

describe("sesi", () => {
  it("/me butuh token yang valid", async () => {
    expect((await env.app.inject({ url: "/api/auth/me" })).statusCode).toBe(401)
    expect((await env.app.inject({ url: "/api/auth/me", headers: bearer("palsu") })).statusCode).toBe(401)

    const token = await login(env.app, "budi@bps.go.id", "passwordLama")
    const res = await env.app.inject({ url: "/api/auth/me", headers: bearer(token) })
    expect(res.statusCode).toBe(200)
    expect(res.json().user.nama).toBe("Budi Santoso")
  })

  it("logout mematikan token", async () => {
    const token = await login(env.app, "budi@bps.go.id", "passwordLama")
    const out = await env.app.inject({ method: "POST", url: "/api/auth/logout", headers: bearer(token) })
    expect(out.statusCode).toBe(200)
    expect((await env.app.inject({ url: "/api/auth/me", headers: bearer(token) })).statusCode).toBe(401)
  })

  it("logout tanpa body tetap diterima walau Content-Type JSON (aplikasi lama)", async () => {
    const token = await login(env.app, "budi@bps.go.id", "passwordLama")
    const out = await env.app.inject({
      method: "POST",
      url: "/api/auth/logout",
      headers: { ...bearer(token), "content-type": "application/json" }
    })
    expect(out.statusCode).toBe(200)
    expect((await env.app.inject({ url: "/api/auth/me", headers: bearer(token) })).statusCode).toBe(401)
  })

  it("JSON rusak dan prototype poisoning tetap ditolak", async () => {
    for (const payload of ["{rusak", '{"__proto__":{"x":1},"email":"a@b.c","password":"x"}']) {
      const res = await env.app.inject({
        method: "POST",
        url: "/api/auth/login",
        headers: { "content-type": "application/json" },
        payload
      })
      expect(res.statusCode).toBe(400)
    }
  })

  it("sesi kedaluwarsa ditolak, sesi aktif diperpanjang", async () => {
    const expired = await login(env.app, "budi@bps.go.id", "passwordLama")
    await env.db.query("UPDATE sessions SET expires_at = NOW() - interval '1 minute'")
    expect((await env.app.inject({ url: "/api/auth/me", headers: bearer(expired) })).statusCode).toBe(401)

    const token = await login(env.app, "budi@bps.go.id", "passwordLama")
    await env.db.query(
      "UPDATE sessions SET last_used_at = NOW() - interval '2 hours', expires_at = NOW() + interval '1 day' WHERE expires_at > NOW()"
    )
    expect((await env.app.inject({ url: "/api/auth/me", headers: bearer(token) })).statusCode).toBe(200)
    const { rows } = await env.db.query("SELECT expires_at FROM sessions WHERE expires_at > NOW()")
    expect(rows[0].expires_at.getTime()).toBeGreaterThan(Date.now() + 29 * 24 * 3600 * 1000)
  })
})

describe("rate limit login", () => {
  it("dibatasi per IP + email: satu kantor (IP sama) tidak saling mengunci", async () => {
    const attempt = (email: string) =>
      env.app.inject({
        method: "POST",
        url: "/api/auth/login",
        remoteAddress: "10.9.8.7",
        payload: { email, password: "salahsalah" }
      })
    const codes: number[] = []
    for (let i = 0; i < 11; i++) codes.push((await attempt("budi@bps.go.id")).statusCode)
    expect(codes.slice(0, 10).every((c) => c === 401)).toBe(true)
    expect(codes[10]).toBe(429)

    // Pegawai lain dari IP yang sama tetap bisa mencoba login.
    expect((await attempt("siti@bps.go.id")).statusCode).toBe(401)
  })
})

describe("health & CORS", () => {
  it("health check", async () => {
    const res = await env.app.inject({ url: "/health" })
    expect(res.json()).toEqual({ status: "ok" })
  })

  it("mengizinkan origin terdaftar (termasuk wildcard localhost) dan menolak yang lain", async () => {
    const preflight = (origin: string) =>
      env.app.inject({
        method: "OPTIONS",
        url: "/api/auth/login",
        headers: { origin, "access-control-request-method": "POST" }
      })
    expect((await preflight("https://pantau.vercel.app")).headers["access-control-allow-origin"]).toBe(
      "https://pantau.vercel.app"
    )
    expect((await preflight("http://localhost:54321")).headers["access-control-allow-origin"]).toBe(
      "http://localhost:54321"
    )
    expect((await preflight("https://jahat.example.com")).headers["access-control-allow-origin"]).toBeUndefined()
  })
})
