import type { FastifyInstance } from "fastify"

import { currentUser } from "../auth.js"
import type { AppContext } from "../app.js"
import { notFound } from "../errors.js"
import { idParams, uuid } from "./schemas.js"

// Bentuk respons sama dengan `laporan.select('*, users(nama), kegiatan(judul)')`.
// `source` bisa tabel laporan atau CTE hasil INSERT ... RETURNING *.
const selectLaporan = (source = "laporan") => `
  SELECT l.*,
         json_build_object('nama', u.nama) AS users,
         json_build_object('judul', k.judul) AS kegiatan
    FROM ${source} l
    LEFT JOIN users u ON u.id = l.user_id
    LEFT JOIN kegiatan k ON k.id = l.kegiatan_id`

interface LaporanQuery {
  user_id?: string
  kegiatan_id?: string
  from?: string
  to?: string
}

export async function laporanRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth } = ctx

  // Pegawai hanya bisa melihat laporannya sendiri; admin bisa semua.
  app.get<{ Querystring: LaporanQuery }>(
    "/api/laporan",
    {
      preHandler: auth.requireAuth,
      schema: {
        querystring: {
          type: "object",
          properties: {
            user_id: uuid,
            kegiatan_id: uuid,
            from: { type: "string", maxLength: 40 },
            to: { type: "string", maxLength: 40 }
          }
        }
      }
    },
    async (request) => {
      const user = currentUser(request)
      const q = request.query
      const userId = user.role === "admin" ? (q.user_id ?? null) : user.id
      const { rows } = await db.query(
        `${selectLaporan()}
          WHERE ($1::uuid IS NULL OR l.user_id = $1)
            AND ($2::uuid IS NULL OR l.kegiatan_id = $2)
            AND ($3::timestamptz IS NULL OR l.created_at >= $3)
            AND ($4::timestamptz IS NULL OR l.created_at <= $4)
          ORDER BY l.created_at DESC`,
        [userId, q.kegiatan_id ?? null, q.from ?? null, q.to ?? null]
      )
      return rows
    }
  )

  app.get<{ Params: { id: string } }>(
    "/api/laporan/:id",
    { preHandler: auth.requireAuth, schema: { params: idParams } },
    async (request) => {
      const user = currentUser(request)
      const { rows } = await db.query(`${selectLaporan()} WHERE l.id = $1 AND ($2::boolean OR l.user_id = $3)`, [
        request.params.id,
        user.role === "admin",
        user.id
      ])
      if (!rows[0]) throw notFound("Laporan tidak ditemukan.")
      return rows[0]
    }
  )

  app.post<{ Body: { kegiatan_id: string; image_url: string; deskripsi?: string | null } }>(
    "/api/laporan",
    {
      preHandler: auth.requireAuth,
      schema: {
        body: {
          type: "object",
          required: ["kegiatan_id", "image_url"],
          properties: {
            kegiatan_id: uuid,
            image_url: { type: "string", minLength: 1, maxLength: 2000 },
            deskripsi: { type: ["string", "null"], maxLength: 5000 }
          }
        }
      }
    },
    async (request) => {
      const b = request.body
      const { rows } = await db.query(
        `WITH inserted AS (
           INSERT INTO laporan (user_id, kegiatan_id, image_url, deskripsi)
           VALUES ($1, $2, $3, $4) RETURNING *
         )
         ${selectLaporan("inserted")}`,
        [currentUser(request).id, b.kegiatan_id, b.image_url, b.deskripsi || null]
      )
      return rows[0]
    }
  )
}
