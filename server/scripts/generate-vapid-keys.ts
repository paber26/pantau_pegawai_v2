/**
 * Buat pasangan kunci VAPID untuk pengingat harian (notifikasi web).
 * Cukup sekali; salin kedua baris hasilnya ke `.env` di VPS, lalu
 * `docker compose up -d api`.
 *
 * Di VPS:
 *   docker compose run --rm --no-deps api node dist/scripts/generate-vapid-keys.js
 *
 * Jangan ganti kunci yang sudah dipakai: perangkat yang sudah mengaktifkan
 * pengingat harus mengaktifkannya ulang.
 */
import webpush from "web-push"

const { publicKey, privateKey } = webpush.generateVAPIDKeys()
console.log(`VAPID_PUBLIC_KEY=${publicKey}`)
console.log(`VAPID_PRIVATE_KEY=${privateKey}`)
