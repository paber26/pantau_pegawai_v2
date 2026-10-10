import type { FastifyInstance } from "fastify"

import { currentUser } from "../auth.js"
import type { AppContext } from "../app.js"
import { notFound } from "../errors.js"
import { uuid } from "./schemas.js"

interface PenugasanKey {
  user_id: string
  kegiatan_id: string
}

const keySchema = {
  type: "object",
  required: ["user_id", "kegiatan_id"],
  properties: { user_id: uuid, kegiatan_id: uuid }
} as const

export async function penugasanRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth } = ctx

  // Bentuk respons sama dengan `penugasan.select('*, users(*)')` di Supabase.
  app.get<{ Querystring: { kegiatan_id: string } }>(
    "/api/penugasan",
    {
      preHandler: auth.requireAuth,
      schema: { querystring: { type: "object", required: ["kegiatan_id"], properties: { kegiatan_id: uuid } } }
    },
    async (request) => {
      const user = currentUser(request)
      const { rows } = await db.query(
        `SELECT p.*,
                json_build_object('id', u.id, 'nama', u.nama, 'email', u.email, 'jabatan', u.jabatan,
                                  'unit_kerja', u.unit_kerja, 'role', u.role, 'created_at', u.created_at) AS users
           FROM penugasan p
           JOIN users u ON u.id = p.user_id
          WHERE p.kegiatan_id = $1 AND ($2::boolean OR p.user_id = $3)
          ORDER BY u.nama ASC`,
        [request.query.kegiatan_id, user.role === "admin", user.id]
      )
      return rows
    }
  )

  app.post<{ Body: PenugasanKey }>(
    "/api/penugasan",
    { preHandler: auth.requireAdmin, schema: { body: keySchema } },
    async (request) => {
      const { rows } = await db.query("INSERT INTO penugasan (user_id, kegiatan_id) VALUES ($1, $2) RETURNING *", [
        request.body.user_id,
        request.body.kegiatan_id
      ])
      return rows[0]
    }
  )

  app.delete<{ Querystring: PenugasanKey }>(
    "/api/penugasan",
    { preHandler: auth.requireAdmin, schema: { querystring: keySchema } },
    async (request) => {
      const { rowCount } = await db.query("DELETE FROM penugasan WHERE user_id = $1 AND kegiatan_id = $2", [
        request.query.user_id,
        request.query.kegiatan_id
      ])
      if (!rowCount) throw notFound("Penugasan tidak ditemukan.")
      return { success: true }
    }
  )
}
