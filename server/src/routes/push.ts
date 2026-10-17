/**
 * Pengaturan pengingat harian dari aplikasi (notifikasi web).
 *
 * GET  /api/push/config          kunci publik VAPID + jadwal pengingat
 * POST /api/push/subscriptions   aktifkan pengingat di perangkat ini
 * POST /api/push/unsubscribe     matikan pengingat di perangkat ini
 * POST /api/push/test            kirim notifikasi uji ke perangkat ini
 */
import type { FastifyInstance } from "fastify"

import { currentUser } from "../auth.js"
import type { AppContext } from "../app.js"
import { badRequest, HttpError } from "../errors.js"
import { isAllowedPushEndpoint, PushGoneError } from "../push.js"

const HARI = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]

/** [1,2,3,4,5] → "Senin–Jumat"; hari tidak berurutan → "Senin, Rabu, Jumat". */
export function describeDays(days: number[]): string {
  const sorted = [...days].sort((a, b) => a - b)
  const consecutive = sorted.every((d, i) => i === 0 || d === sorted[i - 1] + 1)
  if (sorted.length > 2 && consecutive) return `${HARI[sorted[0] - 1]}–${HARI[sorted[sorted.length - 1] - 1]}`
  return sorted.map((d) => HARI[d - 1]).join(", ")
}

export async function pushRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth, config, push } = ctx

  const requirePush = () => {
    if (!push || !config.vapid) throw new HttpError(503, "Pengingat harian belum diaktifkan di server.")
    return push
  }

  app.get("/api/push/config", { preHandler: auth.requireAuth }, async () => ({
    enabled: push !== null && config.vapid !== null,
    public_key: push ? (config.vapid?.publicKey ?? null) : null,
    reminder_time: config.reminder.time,
    reminder_days: config.reminder.days,
    reminder_days_label: describeDays(config.reminder.days)
  }))

  app.post<{ Body: { endpoint: string; keys: { p256dh: string; auth: string } } }>(
    "/api/push/subscriptions",
    {
      preHandler: auth.requireAuth,
      schema: {
        body: {
          type: "object",
          required: ["endpoint", "keys"],
          properties: {
            endpoint: { type: "string", maxLength: 1000 },
            keys: {
              type: "object",
              required: ["p256dh", "auth"],
              properties: {
                p256dh: { type: "string", minLength: 1, maxLength: 200 },
                auth: { type: "string", minLength: 1, maxLength: 100 }
              }
            }
          }
        }
      }
    },
    async (request) => {
      requirePush()
      const user = currentUser(request)
      const { endpoint, keys } = request.body
      if (!isAllowedPushEndpoint(endpoint)) throw badRequest("Alamat layanan notifikasi tidak dikenal.")

      // Satu perangkat (endpoint) hanya milik satu sesi: login ulang/ganti
      // akun di perangkat yang sama memindahkan langganannya.
      await db.query(
        `INSERT INTO push_subscriptions (user_id, session_id, endpoint, p256dh, auth)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (endpoint) DO UPDATE
           SET user_id = EXCLUDED.user_id, session_id = EXCLUDED.session_id,
               p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth`,
        [user.id, user.sessionId, endpoint, keys.p256dh, keys.auth]
      )
      return { success: true }
    }
  )

  app.post<{ Body: { endpoint: string } }>(
    "/api/push/unsubscribe",
    {
      preHandler: auth.requireAuth,
      schema: {
        body: {
          type: "object",
          required: ["endpoint"],
          properties: { endpoint: { type: "string", maxLength: 1000 } }
        }
      }
    },
    async (request) => {
      const user = currentUser(request)
      await db.query("DELETE FROM push_subscriptions WHERE endpoint = $1 AND user_id = $2", [
        request.body.endpoint,
        user.id
      ])
      return { success: true }
    }
  )

  app.post(
    "/api/push/test",
    {
      preHandler: auth.requireAuth,
      config: {
        rateLimit: {
          max: 5,
          timeWindow: "10 minutes",
          keyGenerator: (req) => `push-test|${req.headers.authorization ?? req.ip}`
        }
      }
    },
    async (request) => {
      const sender = requirePush()
      const user = currentUser(request)
      const { rows } = await db.query<{ id: string; endpoint: string; p256dh: string; auth: string }>(
        "SELECT id, endpoint, p256dh, auth FROM push_subscriptions WHERE session_id = $1",
        [user.sessionId]
      )
      if (rows.length === 0) throw badRequest("Pengingat belum aktif di perangkat ini.")

      const jam = config.reminder.time.replace(":", ".")
      let sent = 0
      for (const row of rows) {
        try {
          await sender.send(row, {
            title: "Notifikasi Pawai aktif",
            body: `Pengingat dikirim ${describeDays(config.reminder.days)} pukul ${jam} bila belum ada dokumentasi hari itu.`,
            url: "/#/pegawai/dokumentasi",
            tag: "pengingat-uji"
          })
          sent++
        } catch (err) {
          if (err instanceof PushGoneError) await db.query("DELETE FROM push_subscriptions WHERE id = $1", [row.id])
          else request.log.warn({ err }, "Notifikasi uji gagal dikirim")
        }
      }
      if (sent === 0) {
        throw new HttpError(502, "Notifikasi uji gagal dikirim. Matikan lalu aktifkan lagi pengingat, kemudian coba lagi.")
      }
      return { sent }
    }
  )
}
