/**
 * Notifikasi web (Web Push) dengan kunci VAPID, untuk pengingat harian.
 *
 * Browser memberi "endpoint" milik layanan push (Google untuk Chrome/Android,
 * Apple untuk Safari/iPhone, Mozilla untuk Firefox). Server mengirim pesan
 * terenkripsi ke endpoint itu; layanan push meneruskannya ke perangkat.
 */
import webpush from "web-push"

import type { VapidConfig } from "./config.js"

export interface PushTarget {
  endpoint: string
  p256dh: string
  auth: string
}

/** Isi notifikasi; dibaca service worker `web/pawai-push-sw.js`. */
export interface PushMessage {
  title: string
  body: string
  /** Halaman yang dibuka saat notifikasi diketuk. */
  url: string
  /** Notifikasi dengan tag sama saling menggantikan. */
  tag: string
}

export interface PushSender {
  /** Melempar `PushGoneError` bila langganan sudah tidak berlaku. */
  send(target: PushTarget, message: PushMessage): Promise<void>
}

/** Layanan push menyatakan langganan sudah tidak ada (404/410): hapus dari database. */
export class PushGoneError extends Error {}

export function createWebPushSender(vapid: VapidConfig): PushSender {
  return {
    async send(target, message) {
      try {
        await webpush.sendNotification(
          { endpoint: target.endpoint, keys: { p256dh: target.p256dh, auth: target.auth } },
          JSON.stringify(message),
          // TTL: pengingat yang belum terkirim (HP mati) tidak berguna lagi setelah 4 jam.
          { vapidDetails: vapid, TTL: 4 * 60 * 60, urgency: "normal", timeout: 15_000 }
        )
      } catch (err) {
        const status = (err as { statusCode?: number }).statusCode
        if (status === 404 || status === 410) throw new PushGoneError(`Langganan push tidak berlaku lagi (${status})`)
        throw err
      }
    }
  }
}

/**
 * Hanya endpoint layanan push yang dikenal, agar server tidak bisa disuruh
 * mengirim request ke alamat sembarang (mis. jaringan internal VPS).
 */
const PUSH_SERVICE_HOSTS = ["fcm.googleapis.com", "push.apple.com", "push.services.mozilla.com", "notify.windows.com"]

export function isAllowedPushEndpoint(endpoint: string): boolean {
  let url: URL
  try {
    url = new URL(endpoint)
  } catch {
    return false
  }
  if (url.protocol !== "https:" || url.port !== "") return false
  return PUSH_SERVICE_HOSTS.some((host) => url.hostname === host || url.hostname.endsWith(`.${host}`))
}
