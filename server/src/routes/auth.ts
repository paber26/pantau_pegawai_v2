import type { FastifyInstance } from "fastify"

import { createSession, currentUser, hashPassword, MIN_PASSWORD_LENGTH, USER_COLUMNS, verifyPassword } from "../auth.js"
import type { AppContext } from "../app.js"
import { badRequest, HttpError, notFound } from "../errors.js"

export async function authRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth, config } = ctx

  app.post<{ Body: { email: string; password: string } }>(
    "/api/auth/login",
    {
      config: {
        // Pegawai satu kantor biasanya berbagi satu IP publik, jadi batasi per IP + email.
        // hook preHandler: dijalankan setelah body diparse agar email terbaca.
        rateLimit: {
          hook: "preHandler",
          max: 10,
          timeWindow: "5 minutes",
          keyGenerator: (req) => `${req.ip}|${String((req.body as { email?: string })?.email ?? "").toLowerCase()}`
        }
      },
      schema: {
        body: {
          type: "object",
          required: ["email", "password"],
          properties: {
            email: { type: "string", minLength: 1, maxLength: 320 },
            password: { type: "string", minLength: 1, maxLength: 200 }
          }
        }
      }
    },
    async (request) => {
      const { email, password } = request.body
      const { rows } = await db.query(
        `SELECT ${USER_COLUMNS}, password_hash FROM users WHERE lower(email) = lower($1)`,
        [email.trim()]
      )
      const row = rows[0]
      if (!row || !(await verifyPassword(password, row.password_hash))) {
        throw new HttpError(401, "Email atau kata sandi salah.")
      }
      const { password_hash: _, ...user } = row
      await db.query("DELETE FROM sessions WHERE user_id = $1 AND expires_at < NOW()", [user.id])
      const token = await createSession(db, user.id, config.sessionTtlDays)
      return { token, user }
    }
  )

  app.get("/api/auth/me", { preHandler: auth.requireAuth }, async (request) => {
    const { rows } = await db.query(`SELECT ${USER_COLUMNS} FROM users WHERE id = $1`, [currentUser(request).id])
    if (!rows[0]) throw notFound("User tidak ditemukan.")
    return { user: rows[0] }
  })

  // Ganti password sendiri. Sesi perangkat ini tetap berlaku; sesi lain
  // dimatikan sehingga perangkat lain harus login ulang dengan password baru.
  app.post<{ Body: { current_password: string; new_password: string } }>(
    "/api/auth/change-password",
    {
      preHandler: auth.requireAuth,
      config: {
        // Batasi tebakan password lama lewat endpoint ini (per akun).
        rateLimit: {
          max: 10,
          timeWindow: "5 minutes",
          keyGenerator: (req) => `ganti-password|${req.headers.authorization ?? req.ip}`
        }
      },
      schema: {
        body: {
          type: "object",
          required: ["current_password", "new_password"],
          properties: {
            current_password: { type: "string", maxLength: 200 },
            new_password: { type: "string", maxLength: 200 }
          }
        }
      }
    },
    async (request) => {
      const user = currentUser(request)
      const { current_password, new_password } = request.body
      if (new_password.length < MIN_PASSWORD_LENGTH) {
        throw badRequest(`Password baru minimal ${MIN_PASSWORD_LENGTH} karakter.`)
      }

      const { rows } = await db.query<{ password_hash: string | null }>(
        "SELECT password_hash FROM users WHERE id = $1",
        [user.id]
      )
      // 400, bukan 401: aplikasi menganggap 401 sebagai sesi habis lalu logout.
      if (!(await verifyPassword(current_password, rows[0]?.password_hash ?? null))) {
        throw badRequest("Password lama salah.")
      }
      if (new_password === current_password) {
        throw badRequest("Password baru harus berbeda dari password lama.")
      }

      await db.query("UPDATE users SET password_hash = $2 WHERE id = $1", [user.id, await hashPassword(new_password)])
      await db.query("DELETE FROM sessions WHERE user_id = $1 AND id <> $2", [user.id, user.sessionId])
      return { success: true, message: "Password berhasil diubah" }
    }
  )

  app.post("/api/auth/logout", { preHandler: auth.requireAuth }, async (request) => {
    await db.query("DELETE FROM sessions WHERE id = $1", [currentUser(request).sessionId])
    return { success: true }
  })
}
