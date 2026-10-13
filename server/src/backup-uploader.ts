/**
 * Salinan backup database di Google Drive.
 *
 * Container `backup` menulis `pantau_YYYYmmdd_HHMMSS.dump` ke folder `backups/`
 * setiap hari. API membaca folder itu (di-mount read-only) dan mengunggah file
 * yang belum ada ke ROOT/Backup Database, memakai akun penulis Drive (OAuth
 * pemilik folder). File backup tidak dibagikan lewat link, dan tidak ada yang
 * dihapus otomatis di Drive.
 */
import { readdir, readFile } from "node:fs/promises"
import { join } from "node:path"

import type { FastifyBaseLogger } from "fastify"

import type { DriveService } from "./drive.js"

export const BACKUP_DRIVE_FOLDER = "Backup Database"
/** Sama dengan nama file dari deploy/backup.sh; file `.tmp` yang masih ditulis tidak cocok. */
const BACKUP_FILE = /^pantau_\d{8}_\d{6}\.dump$/

export interface BackupUploadResult {
  uploaded: string[]
  failed: { name: string; error: unknown }[]
}

/** Unggah file backup di `dir` yang belum ada di Drive, dari yang terlama. */
export async function uploadPendingBackups(drive: DriveService, dir: string): Promise<BackupUploadResult> {
  const local = (await readdir(dir)).filter((name) => BACKUP_FILE.test(name)).sort()
  const result: BackupUploadResult = { uploaded: [], failed: [] }
  if (local.length === 0) return result

  const folderPath = [BACKUP_DRIVE_FOLDER]
  const inDrive = new Set(await drive.listFileNames(folderPath))
  for (const name of local) {
    if (inDrive.has(name)) continue
    try {
      await drive.uploadFile({
        bytes: await readFile(join(dir, name)),
        filename: name,
        mimeType: "application/octet-stream",
        folderPath,
        shareWithLink: false
      })
      result.uploaded.push(name)
    } catch (error) {
      result.failed.push({ name, error })
    }
  }
  return result
}

/**
 * Jalankan `uploadPendingBackups` satu menit setelah API start, lalu tiap jam.
 * Error hanya di-log; percobaan berikutnya mengulang file yang gagal.
 * Mengembalikan fungsi untuk menghentikan jadwal.
 */
export function scheduleBackupUploads(
  drive: DriveService,
  dir: string,
  log: FastifyBaseLogger,
  options: { firstDelayMs?: number; intervalMs?: number } = {}
): () => void {
  let running = false
  const run = async () => {
    if (running) return
    running = true
    try {
      const { uploaded, failed } = await uploadPendingBackups(drive, dir)
      for (const name of uploaded) log.info(`Backup diunggah ke Drive (${BACKUP_DRIVE_FOLDER}): ${name}`)
      for (const { name, error } of failed) log.error({ err: error }, `Gagal mengunggah backup ${name} ke Drive`)
    } catch (err) {
      log.error({ err }, "Gagal memeriksa backup untuk Drive")
    } finally {
      running = false
    }
  }

  let interval: NodeJS.Timeout | undefined
  const first = setTimeout(() => {
    void run()
    interval = setInterval(() => void run(), options.intervalMs ?? 60 * 60 * 1000)
    interval.unref()
  }, options.firstDelayMs ?? 60 * 1000)
  first.unref()

  return () => {
    clearTimeout(first)
    clearInterval(interval)
  }
}
