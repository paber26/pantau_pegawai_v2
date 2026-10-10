import type { FastifyInstance } from "fastify"

import { currentUser } from "../auth.js"
import type { AppContext } from "../app.js"
import { forbidden, notFound } from "../errors.js"
import { date, idParams, uuid } from "./schemas.js"

interface KegiatanBody {
  judul: string
  deskripsi?: string | null
  deadline: string
}

const kegiatanBody = {
  type: "object",
  required: ["judul", "deadline"],
  properties: {
    judul: { type: "string", minLength: 1, maxLength: 500 },
    deskripsi: { type: ["string", "null"], maxLength: 5000 },
    deadline: date
  }
} as const

export async function kegiatanRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth } = ctx

  // ?assigned_to=<userId> → kegiatan yang ditugaskan ke user tersebut
  // (pegawai hanya boleh melihat penugasannya sendiri).
  app.get<{ Querystring: { assigned_to?: string } }>(
    "/api/kegiatan",
    {
      preHandler: auth.requireAuth,
      schema: { querystring: { type: "object", properties: { assigned_to: uuid } } }
    },
    async (request) => {
      const { assigned_to } = request.query
      if (assigned_to) {
        const user = currentUser(request)
        if (user.role !== "admin" && assigned_to !== user.id) throw forbidden()
        const { rows } = await db.query(
          `SELECT k.* FROM penugasan p JOIN kegiatan k ON k.id = p.kegiatan_id
            WHERE p.user_id = $1
            ORDER BY k.deadline ASC`,
          [assigned_to]
        )
        return rows
      }
      const { rows } = await db.query("SELECT * FROM kegiatan ORDER BY deadline ASC")
      return rows
    }
  )

  app.get<{ Params: { id: string } }>(
    "/api/kegiatan/:id",
    { preHandler: auth.requireAuth, schema: { params: idParams } },
    async (request) => {
      const { rows } = await db.query("SELECT * FROM kegiatan WHERE id = $1", [request.params.id])
      if (!rows[0]) throw notFound("Kegiatan tidak ditemukan.")
      return rows[0]
    }
  )

  app.post<{ Body: KegiatanBody }>(
    "/api/kegiatan",
    { preHandler: auth.requireAdmin, schema: { body: kegiatanBody } },
    async (request) => {
      const b = request.body
      const { rows } = await db.query(
        "INSERT INTO kegiatan (judul, deskripsi, deadline) VALUES ($1, $2, $3) RETURNING *",
        [b.judul.trim(), b.deskripsi || null, b.deadline]
      )
      return rows[0]
    }
  )

  app.patch<{ Params: { id: string }; Body: KegiatanBody }>(
    "/api/kegiatan/:id",
    { preHandler: auth.requireAdmin, schema: { params: idParams, body: kegiatanBody } },
    async (request) => {
      const b = request.body
      const { rows } = await db.query(
        "UPDATE kegiatan SET judul = $2, deskripsi = $3, deadline = $4 WHERE id = $1 RETURNING *",
        [request.params.id, b.judul.trim(), b.deskripsi || null, b.deadline]
      )
      if (!rows[0]) throw notFound("Kegiatan tidak ditemukan.")
      return rows[0]
    }
  )

  app.delete<{ Params: { id: string } }>(
    "/api/kegiatan/:id",
    { preHandler: auth.requireAdmin, schema: { params: idParams } },
    async (request) => {
      const { rowCount } = await db.query("DELETE FROM kegiatan WHERE id = $1", [request.params.id])
      if (!rowCount) throw notFound("Kegiatan tidak ditemukan.")
      return { success: true }
    }
  )

  // Tambah banyak proyek sekaligus; judul yang sudah ada dilewati.
  app.post<{ Body: { judul_list: string[]; deadline: string } }>(
    "/api/kegiatan/bulk",
    {
      preHandler: auth.requireAdmin,
      schema: {
        body: {
          type: "object",
          required: ["judul_list", "deadline"],
          properties: {
            judul_list: { type: "array", maxItems: 1000, items: { type: "string", minLength: 1, maxLength: 500 } },
            deadline: date
          }
        }
      }
    },
    async (request) => {
      const { judul_list, deadline } = request.body
      const { rows: existing } = await db.query<{ judul: string }>("SELECT judul FROM kegiatan")
      const existingTitles = new Set(existing.map((r) => r.judul))
      const newItems = [...new Set(judul_list)].filter((judul) => !existingTitles.has(judul))

      if (newItems.length > 0) {
        await db.query(
          "INSERT INTO kegiatan (judul, deadline) SELECT unnest($1::text[]), $2::date",
          [newItems, deadline]
        )
      }
      return { inserted: newItems.length, skipped: judul_list.length - newItems.length }
    }
  )
}
