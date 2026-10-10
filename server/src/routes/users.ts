/**
 * Data pegawai (tabel users). Menggantikan query `users` dari client serta
 * Edge Function admin-create-user, admin-delete-user, admin-reset-password.
 */
import type { FastifyInstance } from "fastify"

import { currentUser, deleteSessionsOfUser, hashPassword, MIN_PASSWORD_LENGTH, USER_COLUMNS } from "../auth.js"
import type { AppContext } from "../app.js"
import { badRequest, notFound } from "../errors.js"
import { idParams } from "./schemas.js"

interface UserBody {
  nama: string
  email: string
  password: string
  jabatan?: string | null
  unit_kerja?: string | null
  role?: "admin" | "pegawai"
}

const nullableText = { type: ["string", "null"], maxLength: 500 }
const role = { type: "string", enum: ["admin", "pegawai"] }

export async function userRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth } = ctx

  // Semua user yang login boleh membaca daftar pegawai (dipakai untuk filter
  // dokumentasi). Kolom password_hash tidak pernah ikut.
  app.get("/api/users", { preHandler: auth.requireAuth }, async () => {
    const { rows } = await db.query(`SELECT ${USER_COLUMNS} FROM users ORDER BY nama ASC`)
    return rows
  })

  app.get<{ Params: { id: string } }>(
    "/api/users/:id",
    { preHandler: auth.requireAuth, schema: { params: idParams } },
    async (request) => {
      const { rows } = await db.query(`SELECT ${USER_COLUMNS} FROM users WHERE id = $1`, [request.params.id])
      if (!rows[0]) throw notFound("Pegawai tidak ditemukan.")
      return rows[0]
    }
  )

  app.post<{ Body: UserBody }>(
    "/api/users",
    {
      preHandler: auth.requireAdmin,
      schema: {
        body: {
          type: "object",
          required: ["nama", "email", "password"],
          properties: {
            nama: { type: "string", minLength: 1, maxLength: 200 },
            email: { type: "string", minLength: 3, maxLength: 320 },
            password: { type: "string", minLength: MIN_PASSWORD_LENGTH, maxLength: 200 },
            jabatan: nullableText,
            unit_kerja: nullableText,
            role
          }
        }
      }
    },
    async (request) => {
      const b = request.body
      const email = b.email.trim()
      if (!email.includes("@")) throw badRequest("Format email tidak valid.")
      const { rows } = await db.query(
        `INSERT INTO users (nama, email, jabatan, unit_kerja, role, password_hash)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING ${USER_COLUMNS}`,
        [b.nama.trim(), email, b.jabatan || null, b.unit_kerja || null, b.role ?? "pegawai", await hashPassword(b.password)]
      )
      return { success: true, user: rows[0] }
    }
  )

  // Hanya admin: mencegah pegawai mengubah role dirinya sendiri menjadi admin.
  app.patch<{ Params: { id: string }; Body: Omit<UserBody, "email" | "password"> }>(
    "/api/users/:id",
    {
      preHandler: auth.requireAdmin,
      schema: {
        params: idParams,
        body: {
          type: "object",
          required: ["nama", "role"],
          properties: {
            nama: { type: "string", minLength: 1, maxLength: 200 },
            jabatan: nullableText,
            unit_kerja: nullableText,
            role
          }
        }
      }
    },
    async (request) => {
      const b = request.body
      const { rows } = await db.query(
        `UPDATE users SET nama = $2, jabatan = $3, unit_kerja = $4, role = $5
          WHERE id = $1
          RETURNING ${USER_COLUMNS}`,
        [request.params.id, b.nama.trim(), b.jabatan || null, b.unit_kerja || null, b.role]
      )
      if (!rows[0]) throw notFound("Pegawai tidak ditemukan.")
      return rows[0]
    }
  )

  app.delete<{ Params: { id: string } }>(
    "/api/users/:id",
    { preHandler: auth.requireAdmin, schema: { params: idParams } },
    async (request) => {
      if (request.params.id === currentUser(request).id) {
        throw badRequest("Tidak bisa menghapus akun sendiri.")
      }
      // Cascade: sesi, penugasan, laporan, dan dokumentasi user ikut terhapus.
      const { rowCount } = await db.query("DELETE FROM users WHERE id = $1", [request.params.id])
      if (!rowCount) throw notFound("Pegawai tidak ditemukan.")
      return { success: true }
    }
  )

  app.post<{ Params: { id: string }; Body: { new_password: string } }>(
    "/api/users/:id/reset-password",
    {
      preHandler: auth.requireAdmin,
      schema: {
        params: idParams,
        body: {
          type: "object",
          required: ["new_password"],
          properties: { new_password: { type: "string", maxLength: 200 } }
        }
      }
    },
    async (request) => {
      if (request.body.new_password.length < MIN_PASSWORD_LENGTH) {
        throw badRequest(`Password minimal ${MIN_PASSWORD_LENGTH} karakter.`)
      }
      const { rowCount } = await db.query("UPDATE users SET password_hash = $2 WHERE id = $1", [
        request.params.id,
        await hashPassword(request.body.new_password)
      ])
      if (!rowCount) throw notFound("Pegawai tidak ditemukan.")
      // Paksa login ulang di semua perangkat dengan password baru.
      await deleteSessionsOfUser(db, request.params.id)
      return { success: true, message: "Password berhasil diubah" }
    }
  )
}
