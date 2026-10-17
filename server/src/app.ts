import cors from "@fastify/cors"
import multipart from "@fastify/multipart"
import rateLimit from "@fastify/rate-limit"
import Fastify, { type FastifyInstance, type FastifyServerOptions } from "fastify"

import { authHooks, type AuthHooks } from "./auth.js"
import type { Config } from "./config.js"
import type { Db } from "./db.js"
import type { DriveService } from "./drive.js"
import { errorHandler } from "./errors.js"
import type { PushSender } from "./push.js"
import { authRoutes } from "./routes/auth.js"
import { dashboardRoutes } from "./routes/dashboard.js"
import { dokumentasiRoutes } from "./routes/dokumentasi.js"
import { imageRoutes } from "./routes/images.js"
import { importRoutes } from "./routes/import.js"
import { kegiatanRoutes } from "./routes/kegiatan.js"
import { laporanRoutes } from "./routes/laporan.js"
import { penugasanRoutes } from "./routes/penugasan.js"
import { pushRoutes } from "./routes/push.js"
import { uploadRoutes } from "./routes/uploads.js"
import { userRoutes } from "./routes/users.js"

export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024

export interface AppContext {
  config: Config
  db: Db
  auth: AuthHooks
  /** null bila kredensial Google belum dikonfigurasi (upload & gambar → 503). */
  drive: DriveService | null
  /** null bila kunci VAPID belum diisi (pengingat harian → 503). */
  push: PushSender | null
}

/** Cocokkan origin dengan daftar CORS_ORIGINS; `*` = wildcard (mis. http://localhost:*). */
export function originMatcher(patterns: string[]): (origin: string) => boolean {
  const regexes = patterns.map(
    (p) => new RegExp(`^${p.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[^/]*")}$`)
  )
  return (origin) => regexes.some((r) => r.test(origin))
}

export async function buildApp(
  deps: { config: Config; db: Db; drive: DriveService | null; push?: PushSender | null },
  opts: FastifyServerOptions = {}
): Promise<FastifyInstance> {
  // trustProxy: API berjalan di belakang Caddy, jadi IP asli ada di X-Forwarded-For.
  const app = Fastify({ trustProxy: true, ...opts })
  const ctx: AppContext = { ...deps, push: deps.push ?? null, auth: authHooks(deps.db, deps.config.sessionTtlDays) }

  app.setErrorHandler(errorHandler)

  // Aplikasi versi lama mengirim "Content-Type: application/json" juga pada
  // request tanpa body (DELETE, logout); Fastify menolaknya dengan 400.
  // Body kosong diperlakukan sebagai tanpa body; selebihnya parser bawaan.
  const parseJson = app.getDefaultJsonParser("error", "error")
  app.removeContentTypeParser("application/json")
  app.addContentTypeParser("application/json", { parseAs: "string" }, (request, body, done) => {
    if (typeof body === "string" && body.trim() === "") return done(null, undefined)
    parseJson(request, body as string, done)
  })

  const isAllowedOrigin = originMatcher(deps.config.corsOrigins)
  await app.register(cors, {
    delegator: (req, cb) => {
      // Gambar boleh diambil dari mana saja (dipakai langsung oleh <img>).
      if (req.url?.startsWith("/api/images")) return cb(null, { origin: "*", methods: ["GET"] })
      cb(null, {
        origin: (origin, done) => done(null, !origin || isAllowedOrigin(origin)),
        methods: ["GET", "POST", "PATCH", "DELETE"],
        allowedHeaders: ["Authorization", "Content-Type"],
        maxAge: 600
      })
    }
  })
  await app.register(rateLimit, { global: false })
  await app.register(multipart, { limits: { fileSize: MAX_UPLOAD_BYTES, files: 1, fields: 10 } })

  app.get("/health", async () => {
    await deps.db.query("SELECT 1")
    return { status: "ok" }
  })

  for (const routes of [
    authRoutes,
    userRoutes,
    kegiatanRoutes,
    penugasanRoutes,
    laporanRoutes,
    dokumentasiRoutes,
    uploadRoutes,
    imageRoutes,
    dashboardRoutes,
    importRoutes,
    pushRoutes
  ]) {
    await app.register(async (instance) => routes(instance, ctx))
  }

  return app
}
