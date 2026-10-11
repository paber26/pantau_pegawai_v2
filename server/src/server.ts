import { buildApp } from "./app.js"
import { loadConfig } from "./config.js"
import { createPool } from "./db.js"
import { createGoogleDriveService, type DriveService } from "./drive.js"
import { runMigrations } from "./migrate.js"

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

const app = await buildApp({ config, db, drive }, { logger: { level: process.env.LOG_LEVEL ?? "info" } })

const shutdown = async () => {
  await app.close()
  await db.end()
  process.exit(0)
}
process.on("SIGTERM", shutdown)
process.on("SIGINT", shutdown)

await app.listen({ host: "0.0.0.0", port: config.port })
