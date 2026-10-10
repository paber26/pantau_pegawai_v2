import type { FastifyInstance } from "fastify"

import { createSession, currentUser, USER_COLUMNS, verifyPassword } from "../auth.js"
import type { AppContext } from "../app.js"
import { HttpError, notFound } from "../errors.js"

export async function authRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth, config } = ctx

  app.post<{ Body: { email: string; password: string } }>(
    "/api/auth/login",
    {
      config: {
        // Pegawai satu kantor biasanya berbagi satu IP publik, jadi batasi per IP + email.
        rateLimit: {
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
      const token = await createSession(db, user.id, config.sessionTtlDays)
      return { token, user }
    }
  )

  app.get("/api/auth/me", { preHandler: auth.requireAuth }, async (request) => {
    const { rows } = await db.query(`SELECT ${USER_COLUMNS} FROM users WHERE id = $1`, [currentUser(request).id])
    if (!rows[0]) throw notFound("User tidak ditemukan.")
    return { user: rows[0] }
  })

  app.post("/api/auth/logout", { preHandler: auth.requireAuth }, async (request) => {
    await db.query("DELETE FROM sessions WHERE id = $1", [currentUser(request).sessionId])
    return { success: true }
  })
}
