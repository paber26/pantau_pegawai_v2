import type { FastifyInstance } from "fastify"
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest"

import { buildApp } from "../src/app.js"
import { reminderFromEnv, vapidFromEnv } from "../src/config.js"
import { isAllowedPushEndpoint, PushGoneError, type PushMessage, type PushSender, type PushTarget } from "../src/push.js"
import { reminderDueDate, reminderMessage, sendDailyReminders } from "../src/reminders.js"
import { describeDays } from "../src/routes/push.js"
import { bearer, login, seedUsers, setup, teardown, testConfig, type TestEnv } from "./helpers.js"

/** Pengirim palsu: mencatat pesan; endpoint di `gone` → 410, di `broken` → error biasa. */
class FakePushSender implements PushSender {
  sent: { target: PushTarget; message: PushMessage }[] = []
  gone = new Set<string>()
  broken = new Set<string>()

  async send(target: PushTarget, message: PushMessage) {
    if (this.gone.has(target.endpoint)) throw new PushGoneError("410")
    if (this.broken.has(target.endpoint)) throw new Error("layanan push sibuk")
    this.sent.push({ target, message })
  }
}

const endpoint = (name: string) => `https://fcm.googleapis.com/fcm/send/${name}`
const subscription = (name: string) => ({ endpoint: endpoint(name), keys: { p256dh: `p256dh-${name}`, auth: `auth-${name}` } })

let env: TestEnv
let s: Awaited<ReturnType<typeof seedUsers>>
let app: FastifyInstance
let sender: FakePushSender

beforeAll(async () => {
  env = await setup()
  s = await seedUsers(env)
})
afterAll(async () => {
  await app?.close()
  await teardown(env)
})
beforeEach(async () => {
  await app?.close()
  sender = new FakePushSender()
  app = await buildApp({ config: testConfig(), db: env.db, drive: null, push: sender })
  await env.db.query("DELETE FROM push_subscriptions")
  await env.db.query("DELETE FROM reminder_runs")
  await env.db.query("DELETE FROM dokumentasi")
})

async function subscribe(token: string, name: string) {
  const res = await app.inject({
    method: "POST",
    url: "/api/push/subscriptions",
    headers: bearer(token),
    payload: subscription(name)
  })
  expect(res.statusCode).toBe(200)
}

describe("/api/push", () => {
  it("config: butuh login, berisi kunci publik dan jadwal", async () => {
    expect((await app.inject({ url: "/api/push/config" })).statusCode).toBe(401)
    const res = await app.inject({ url: "/api/push/config", headers: bearer(s.budi) })
    expect(res.json()).toEqual({
      enabled: true,
      public_key: "BTestPublicKey",
      reminder_time: "15:00",
      reminder_days: [1, 2, 3, 4, 5],
      reminder_days_label: "Senin–Jumat"
    })

    // Tanpa kunci VAPID: tidak aktif, dan langganan ditolak 503.
    const off = await env.app.inject({ url: "/api/push/config", headers: bearer(s.budi) })
    expect(off.json()).toMatchObject({ enabled: false, public_key: null })
    const ditolak = await env.app.inject({
      method: "POST",
      url: "/api/push/subscriptions",
      headers: bearer(s.budi),
      payload: subscription("x")
    })
    expect(ditolak.statusCode).toBe(503)
  })

  it("langganan hanya ke layanan push yang dikenal", async () => {
    for (const bad of ["http://fcm.googleapis.com/fcm/send/a", "https://127.0.0.1/x", "https://evil.example/fcm.googleapis.com"]) {
      const res = await app.inject({
        method: "POST",
        url: "/api/push/subscriptions",
        headers: bearer(s.budi),
        payload: { endpoint: bad, keys: { p256dh: "a", auth: "b" } }
      })
      expect(res.statusCode, bad).toBe(400)
    }
  })

  it("langganan terikat ke sesi: pindah pemilik saat login akun lain; hilang saat logout", async () => {
    await subscribe(s.budi, "hp1")
    const { rows } = await env.db.query("SELECT user_id FROM push_subscriptions")
    expect(rows).toEqual([{ user_id: s.budiId }])

    // Siti login di HP yang sama → langganan pindah ke Siti.
    await subscribe(s.siti, "hp1")
    expect((await env.db.query("SELECT user_id FROM push_subscriptions")).rows).toEqual([{ user_id: s.sitiId }])

    // Logout Siti → langganannya ikut terhapus.
    const token = await login(env.app, "siti@bps.go.id")
    await subscribe(token, "hp2")
    await app.inject({ method: "POST", url: "/api/auth/logout", headers: bearer(token) })
    expect((await env.db.query("SELECT endpoint FROM push_subscriptions")).rows).toEqual([{ endpoint: endpoint("hp1") }])
  })

  it("unsubscribe hanya langganan milik sendiri", async () => {
    await subscribe(s.budi, "hp-budi")
    await app.inject({
      method: "POST",
      url: "/api/push/unsubscribe",
      headers: bearer(s.siti),
      payload: { endpoint: endpoint("hp-budi") }
    })
    expect((await env.db.query("SELECT count(*)::int AS n FROM push_subscriptions")).rows[0].n).toBe(1)

    await app.inject({
      method: "POST",
      url: "/api/push/unsubscribe",
      headers: bearer(s.budi),
      payload: { endpoint: endpoint("hp-budi") }
    })
    expect((await env.db.query("SELECT count(*)::int AS n FROM push_subscriptions")).rows[0].n).toBe(0)
  })

  it("notifikasi uji hanya ke perangkat ini; langganan kedaluwarsa dihapus", async () => {
    const res0 = await app.inject({ method: "POST", url: "/api/push/test", headers: bearer(s.budi) })
    expect(res0.statusCode).toBe(400)

    const laptop = await login(env.app, "budi@bps.go.id")
    await subscribe(s.budi, "hp")
    await subscribe(laptop, "laptop")

    const res = await app.inject({ method: "POST", url: "/api/push/test", headers: bearer(s.budi) })
    expect(res.json()).toEqual({ sent: 1 })
    expect(sender.sent.map((x) => x.target.endpoint)).toEqual([endpoint("hp")])
    expect(sender.sent[0].message.body).toContain("Senin–Jumat pukul 15.00")

    sender.gone.add(endpoint("hp"))
    const gone = await app.inject({ method: "POST", url: "/api/push/test", headers: bearer(s.budi) })
    expect(gone.statusCode).toBe(502)
    expect((await env.db.query("SELECT endpoint FROM push_subscriptions")).rows).toEqual([{ endpoint: endpoint("laptop") }])
  })
})

describe("sendDailyReminders", () => {
  const TANGGAL = "2026-10-14"

  it("hanya pegawai yang belum upload hari itu; sekali per hari", async () => {
    await subscribe(s.budi, "budi")
    await subscribe(s.siti, "siti")
    await subscribe(s.admin, "admin")
    // Siti sudah upload hari itu; dokumentasi Budi yang dihapus tidak dihitung.
    await env.db.query(
      `INSERT INTO dokumentasi (user_id, proyek, tanggal_kegiatan, deleted_at) VALUES
         ($1, 'Rapat', $3, NULL), ($2, 'Dihapus', $3, NOW()), ($2, 'Kemarin', DATE '2026-10-13', NULL)`,
      [s.sitiId, s.budiId, TANGGAL]
    )

    const result = await sendDailyReminders(env.db, sender, TANGGAL)

    expect(result).toEqual({ sent: 1, failed: 0, removed: 0 })
    expect(sender.sent).toHaveLength(1)
    expect(sender.sent[0].target).toEqual({
      id: expect.any(String),
      nama: "Budi Santoso",
      endpoint: endpoint("budi"),
      p256dh: "p256dh-budi",
      auth: "auth-budi"
    })
    expect(sender.sent[0].message).toMatchObject({ title: "Pengingat Dokumentasi", url: "/#/pegawai/dokumentasi" })

    expect(await sendDailyReminders(env.db, sender, TANGGAL)).toBeNull()
    expect(sender.sent).toHaveLength(1)
    expect((await env.db.query("SELECT sent, failed FROM reminder_runs")).rows).toEqual([{ sent: 1, failed: 0 }])
  })

  it("langganan kedaluwarsa dihapus, error lain tidak menghentikan yang lain, sesi habis dilewati", async () => {
    const budiLain = await login(env.app, "budi@bps.go.id")
    const sitiLain = await login(env.app, "siti@bps.go.id")
    await subscribe(s.budi, "budi-hp")
    await subscribe(budiLain, "budi-laptop")
    await subscribe(s.siti, "siti-hp")
    await subscribe(sitiLain, "siti-lama")
    await env.db.query(
      "UPDATE sessions SET expires_at = NOW() - interval '1 day' WHERE id = (SELECT session_id FROM push_subscriptions WHERE endpoint = $1)",
      [endpoint("siti-lama")]
    )
    sender.gone.add(endpoint("budi-hp"))
    sender.broken.add(endpoint("budi-laptop"))

    const result = await sendDailyReminders(env.db, sender, TANGGAL)

    expect(result).toEqual({ sent: 1, failed: 1, removed: 1 })
    expect(sender.sent.map((x) => x.target.endpoint)).toEqual([endpoint("siti-hp")])
    const left = (await env.db.query("SELECT endpoint FROM push_subscriptions ORDER BY endpoint")).rows.map((r) => r.endpoint)
    expect(left).toEqual([endpoint("budi-laptop"), endpoint("siti-hp"), endpoint("siti-lama")])
  })
})

describe("jadwal & konfigurasi", () => {
  const jadwal = { time: "15:00", days: [1, 2, 3, 4, 5] }
  const WITA = "Asia/Makassar" // UTC+8

  it("waktunya kirim: mulai jam pengingat, paling lambat 3 jam sesudahnya, hanya hari terpilih", () => {
    // Rabu 14 Okt 2026
    expect(reminderDueDate(new Date("2026-10-14T06:59:00Z"), WITA, jadwal)).toBeNull() // 14.59
    expect(reminderDueDate(new Date("2026-10-14T07:00:00Z"), WITA, jadwal)).toBe("2026-10-14") // 15.00
    expect(reminderDueDate(new Date("2026-10-14T09:59:00Z"), WITA, jadwal)).toBe("2026-10-14") // 17.59
    expect(reminderDueDate(new Date("2026-10-14T10:00:00Z"), WITA, jadwal)).toBeNull() // 18.00
    // Sabtu 17 Okt 2026
    expect(reminderDueDate(new Date("2026-10-17T07:30:00Z"), WITA, jadwal)).toBeNull()
    expect(reminderDueDate(new Date("2026-10-17T07:30:00Z"), WITA, { time: "15:00", days: [6] })).toBe("2026-10-17")
    // Tanggal mengikuti zona waktu kantor, bukan UTC: 00.30 WITA Kamis = 16.30 UTC Rabu.
    expect(reminderDueDate(new Date("2026-10-14T16:30:00Z"), WITA, { time: "00:15", days: [4] })).toBe("2026-10-15")
  })

  it("isi pesan: nama depan dan tanggal berbahasa Indonesia", () => {
    expect(reminderMessage("Bernaldo Napitupulu S.Tr.Stat.", "2026-10-14").body).toBe(
      "Halo Bernaldo, dokumentasi hari ini (Rabu, 14 Oktober) belum ada. Ketuk untuk mengunggah."
    )
  })

  it("REMINDER_TIME / REMINDER_DAYS", () => {
    expect(reminderFromEnv({})).toEqual({ time: "15:00", days: [1, 2, 3, 4, 5] })
    expect(reminderFromEnv({ REMINDER_TIME: "07:30", REMINDER_DAYS: "1,3,5-6" })).toEqual({
      time: "07:30",
      days: [1, 3, 5, 6]
    })
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {})
    expect(reminderFromEnv({ REMINDER_TIME: "3 sore", REMINDER_DAYS: "senin" })).toEqual({
      time: "15:00",
      days: [1, 2, 3, 4, 5]
    })
    expect(warn).toHaveBeenCalledTimes(2)
    warn.mockRestore()
  })

  it("VAPID: kedua kunci wajib; subjek default URL publik API", () => {
    expect(vapidFromEnv({ VAPID_PUBLIC_KEY: "pub", VAPID_PRIVATE_KEY: "priv" }, "https://api.x")).toEqual({
      publicKey: "pub",
      privateKey: "priv",
      subject: "https://api.x"
    })
    expect(vapidFromEnv({}, "https://api.x")).toBeNull()
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {})
    expect(vapidFromEnv({ VAPID_PUBLIC_KEY: "pub" }, "https://api.x")).toBeNull()
    expect(warn).toHaveBeenCalledOnce()
    warn.mockRestore()
  })

  it("endpoint layanan push yang diizinkan", () => {
    for (const ok of [
      "https://fcm.googleapis.com/fcm/send/abc",
      "https://web.push.apple.com/QGx",
      "https://updates.push.services.mozilla.com/wpush/v2/abc",
      "https://wns2-par02p.notify.windows.com/w/?token=abc"
    ]) {
      expect(isAllowedPushEndpoint(ok), ok).toBe(true)
    }
    for (const bad of [
      "http://fcm.googleapis.com/fcm/send/abc",
      "https://fcm.googleapis.com.evil.example/x",
      "https://fcm.googleapis.com@evil.example/x",
      "https://fcm.googleapis.com:8443/x",
      "https://localhost/x",
      "bukan url"
    ]) {
      expect(isAllowedPushEndpoint(bad), bad).toBe(false)
    }
  })

  it("label hari", () => {
    expect(describeDays([1, 2, 3, 4, 5])).toBe("Senin–Jumat")
    expect(describeDays([1, 2, 3, 4, 5, 6])).toBe("Senin–Sabtu")
    expect(describeDays([5, 1, 3])).toBe("Senin, Rabu, Jumat")
  })
})
