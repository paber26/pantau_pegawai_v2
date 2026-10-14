import { buildApp } from "./app.js"
import { BACKUP_DRIVE_FOLDER, scheduleBackupUploads } from "./backup-uploader.js"
import { loadConfig } from "./config.js"
import { createPool } from "./db.js"
import { createGoogleDriveService, type DriveService } from "./drive.js"
import { runMigrations } from "./migrate.js"
import { createWebPushSender } from "./push.js"
import { scheduleReminders } from "./reminders.js"
import { describeDays } from "./routes/push.js"

const config = loadConfig()
const db = createPool(config.databaseUrl)

await runMigrations(db)

let drive: DriveService | null = null
if (config.googleServiceAccountFile && config.googleDriveRootFolderId) {
  drive = createGoogleDriveService({
    serviceAccountFile: config.googleServiceAccountFile,
    rootFolderId: config.googleDriveRootFolderId,
    oauth: config.googleOAuth
  })
  console.log(
    config.googleOAuth
      ? "Upload foto ke Drive memakai akun OAuth pemilik folder (GOOGLE_OAUTH_*)."
      : "Upload foto ke Drive memakai service account."
  )
} else {
  console.warn("GOOGLE_SERVICE_ACCOUNT_FILE / GOOGLE_DRIVE_ROOT_FOLDER_ID belum diset: upload & gambar tidak aktif.")
}

const push = config.vapid ? createWebPushSender(config.vapid) : null

const app = await buildApp({ config, db, drive, push }, { logger: { level: process.env.LOG_LEVEL ?? "info" } })

let stopReminders = () => {}
if (push) {
  stopReminders = scheduleReminders({
    db,
    sender: push,
    timeZone: config.appTimezone,
    reminder: config.reminder,
    log: app.log
  })
  app.log.info(
    `Pengingat harian aktif: ${describeDays(config.reminder.days)} pukul ${config.reminder.time} (${config.appTimezone}).`
  )
} else {
  app.log.info("VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY belum diisi: pengingat harian tidak aktif.")
}

let stopBackupUploads = () => {}
if (config.backupDir && drive) {
  stopBackupUploads = scheduleBackupUploads(drive, config.backupDir, app.log)
  app.log.info(`Backup di ${config.backupDir} disalin ke Google Drive (folder '${BACKUP_DRIVE_FOLDER}'), dicek tiap jam.`)
} else if (config.backupDir) {
  app.log.warn("BACKUP_DIR diset tetapi Google Drive belum aktif: backup tidak disalin ke Drive.")
}

const shutdown = async () => {
  stopBackupUploads()
  stopReminders()
  await app.close()
  await db.end()
  process.exit(0)
}
process.on("SIGTERM", shutdown)
process.on("SIGINT", shutdown)

await app.listen({ host: "0.0.0.0", port: config.port })
