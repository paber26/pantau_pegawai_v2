/**
 * Pengingat harian: pada jam `REMINDER_TIME` di hari kerja, pegawai yang
 * belum punya dokumentasi untuk hari itu mendapat notifikasi di perangkat
 * yang mengaktifkan pengingat.
 */
import type { FastifyBaseLogger } from "fastify"

import type { ReminderConfig } from "./config.js"
import type { Db } from "./db.js"
import { PushGoneError, type PushMessage, type PushSender } from "./push.js"

/**
 * Bila API baru hidup lebih dari 3 jam setelah jam pengingat (mis. server
 * mati siang hari), pengingat hari itu dilewati agar tidak masuk malam hari.
 */
const LATE_LIMIT_MINUTES = 180
const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

/** Tanggal (YYYY-MM-DD), hari (1 = Senin), dan menit sejak 00:00 di zona waktu kantor. */
export function localTime(now: Date, timeZone: string) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      weekday: "short",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23"
    })
      .formatToParts(now)
      .map((p) => [p.type, p.value])
  )
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    weekday: WEEKDAYS.indexOf(parts.weekday) + 1,
    minutes: Number(parts.hour) * 60 + Number(parts.minute)
  }
}

/** Tanggal lokal bila pengingat hari ini sudah waktunya dikirim; selain itu `null`. */
export function reminderDueDate(now: Date, timeZone: string, reminder: ReminderConfig): string | null {
  const local = localTime(now, timeZone)
  const [hour, minute] = reminder.time.split(":").map(Number)
  const due = hour * 60 + minute
  if (!reminder.days.includes(local.weekday)) return null
  if (local.minutes < due || local.minutes >= due + LATE_LIMIT_MINUTES) return null
  return local.date
}

export function reminderMessage(nama: string, tanggal: string): PushMessage {
  const hari = new Intl.DateTimeFormat("id-ID", {
    weekday: "long",
    day: "numeric",
    month: "long",
    timeZone: "UTC"
  }).format(new Date(`${tanggal}T00:00:00Z`))
  const sapaan = nama.trim().split(/\s+/)[0] || "Anda"
  return {
    title: "Pengingat Dokumentasi",
    body: `Halo ${sapaan}, dokumentasi hari ini (${hari}) belum ada. Ketuk untuk mengunggah.`,
    url: "/#/pegawai/dokumentasi",
    tag: "pengingat-harian"
  }
}

export interface ReminderRunResult {
  sent: number
  failed: number
  removed: number
}

/**
 * Kirim pengingat untuk `tanggal`. Mengembalikan `null` bila hari itu sudah
 * pernah dikirim (dicatat di `reminder_runs`, jadi aman bila API di-restart).
 */
export async function sendDailyReminders(
  db: Db,
  sender: PushSender,
  tanggal: string,
  log?: FastifyBaseLogger
): Promise<ReminderRunResult | null> {
  const run = await db.query("INSERT INTO reminder_runs (tanggal) VALUES ($1) ON CONFLICT DO NOTHING", [tanggal])
  if (run.rowCount === 0) return null

  const result: ReminderRunResult = { sent: 0, failed: 0, removed: 0 }
  try {
    // Hanya pegawai yang belum punya dokumentasi hari itu (sama dengan
    // "belum upload" di dashboard), dan hanya perangkat yang sesinya masih aktif.
    const { rows } = await db.query<{ id: string; nama: string; endpoint: string; p256dh: string; auth: string }>(
      `SELECT ps.id, u.nama, ps.endpoint, ps.p256dh, ps.auth
         FROM push_subscriptions ps
         JOIN users u ON u.id = ps.user_id
         JOIN sessions s ON s.id = ps.session_id AND s.expires_at > NOW()
        WHERE u.role = 'pegawai'
          AND NOT EXISTS (
            SELECT 1 FROM dokumentasi d
             WHERE d.user_id = u.id AND d.tanggal_kegiatan = $1::date AND d.deleted_at IS NULL
          )`,
      [tanggal]
    )
    for (const row of rows) {
      try {
        await sender.send(row, reminderMessage(row.nama, tanggal))
        result.sent++
      } catch (err) {
        if (err instanceof PushGoneError) {
          await db.query("DELETE FROM push_subscriptions WHERE id = $1", [row.id])
          result.removed++
        } else {
          result.failed++
          log?.warn({ err }, `Pengingat untuk ${row.nama} gagal dikirim`)
        }
      }
    }
  } catch (err) {
    // Gagal sebelum mengirim (mis. database): boleh dicoba lagi menit berikutnya.
    if (result.sent === 0) await db.query("DELETE FROM reminder_runs WHERE tanggal = $1", [tanggal])
    throw err
  }

  await db.query("UPDATE reminder_runs SET sent = $2, failed = $3 WHERE tanggal = $1", [
    tanggal,
    result.sent,
    result.failed
  ])
  return result
}

/**
 * Periksa tiap menit apakah pengingat hari ini sudah waktunya dikirim.
 * Mengembalikan fungsi untuk menghentikan jadwal.
 */
export function scheduleReminders(options: {
  db: Db
  sender: PushSender
  timeZone: string
  reminder: ReminderConfig
  log: FastifyBaseLogger
  intervalMs?: number
}): () => void {
  const { db, sender, timeZone, reminder, log } = options
  let running = false
  let doneFor: string | null = null

  const tick = async () => {
    const tanggal = reminderDueDate(new Date(), timeZone, reminder)
    if (!tanggal || tanggal === doneFor || running) return
    running = true
    try {
      const result = await sendDailyReminders(db, sender, tanggal, log)
      doneFor = tanggal
      if (result) {
        log.info(
          `Pengingat harian ${tanggal}: ${result.sent} terkirim, ${result.failed} gagal, ` +
            `${result.removed} langganan kedaluwarsa dihapus.`
        )
      }
    } catch (err) {
      log.error({ err }, "Pengingat harian gagal dijalankan")
    } finally {
      running = false
    }
  }

  const interval = setInterval(() => void tick(), options.intervalMs ?? 60_000)
  interval.unref()
  return () => clearInterval(interval)
}
