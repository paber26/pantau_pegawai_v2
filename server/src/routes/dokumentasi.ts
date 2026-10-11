import type { FastifyInstance } from "fastify"

import { currentUser } from "../auth.js"
import type { AppContext } from "../app.js"
import { forbidden, notFound } from "../errors.js"
import { date, idParams, uuid } from "./schemas.js"

// Bentuk respons sama dengan `dokumentasi.select('*, users(nama, jabatan, unit_kerja)')`,
// ditambah `deleted_by_nama` (nama yang menghapus; null bila tidak terhapus).
// `source` bisa tabel dokumentasi atau CTE hasil INSERT/UPDATE ... RETURNING *
// (baris baru tidak terlihat bila dibaca ulang dari tabel di query yang sama).
const selectDokumentasi = (source = "dokumentasi") => `
  SELECT d.*,
         json_build_object('nama', u.nama, 'jabatan', u.jabatan, 'unit_kerja', u.unit_kerja) AS users,
         du.nama AS deleted_by_nama
    FROM ${source} d
    LEFT JOIN users u ON u.id = d.user_id
    LEFT JOIN users du ON du.id = d.deleted_by`

interface DokumentasiQuery {
  from?: string
  to?: string
  user_id?: string
  year?: number
  /** true = hanya dokumentasi yang dihapus (khusus admin). */
  deleted?: boolean
}

interface DokumentasiBody {
  proyek: string
  tanggal_kegiatan: string
  image_url?: string | null
  catatan?: string | null
  link?: string | null
}

const dokumentasiBody = {
  type: "object",
  required: ["proyek", "tanggal_kegiatan"],
  properties: {
    proyek: { type: "string", minLength: 1, maxLength: 500 },
    tanggal_kegiatan: date,
    image_url: { type: ["string", "null"], maxLength: 2000 },
    catatan: { type: ["string", "null"], maxLength: 10000 },
    link: { type: ["string", "null"], maxLength: 2000 }
  }
} as const

export async function dokumentasiRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth } = ctx

  /**
   * Semua user yang login bisa membaca semua dokumentasi (sama seperti RLS lama).
   * Mengembalikan SEMUA baris yang cocok — tidak ada lagi batas 1000 baris.
   * Dokumentasi yang dihapus tidak ikut; admin melihatnya lewat `?deleted=true`.
   *
   * Urutan: per user → terbaru ditambahkan dulu (halaman "Riwayat Saya");
   * yang dihapus → terbaru dihapus dulu;
   * selain itu → tanggal kegiatan terbaru, lalu waktu penambahan terbaru.
   */
  app.get<{ Querystring: DokumentasiQuery }>(
    "/api/dokumentasi",
    {
      preHandler: auth.requireAuth,
      schema: {
        querystring: {
          type: "object",
          properties: {
            from: date,
            to: date,
            user_id: uuid,
            year: { type: "integer", minimum: 2000, maximum: 2100 },
            deleted: { type: "boolean" }
          }
        }
      }
    },
    async (request) => {
      const q = request.query
      const deleted = q.deleted === true
      if (deleted && currentUser(request).role !== "admin") {
        throw forbidden("Hanya admin yang dapat melihat dokumentasi yang dihapus.")
      }
      const order = deleted
        ? "d.deleted_at DESC"
        : q.user_id
          ? "d.created_at DESC"
          : "d.tanggal_kegiatan DESC, d.created_at DESC"
      const { rows } = await db.query(
        `${selectDokumentasi()}
          WHERE (d.deleted_at IS NOT NULL) = ${deleted ? "TRUE" : "FALSE"}
            AND ($1::date IS NULL OR d.tanggal_kegiatan >= $1)
            AND ($2::date IS NULL OR d.tanggal_kegiatan <= $2)
            AND ($3::uuid IS NULL OR d.user_id = $3)
            AND ($4::int IS NULL OR d.tanggal_kegiatan BETWEEN make_date($4, 1, 1) AND make_date($4, 12, 31))
          ORDER BY ${order}`,
        [q.from ?? null, q.to ?? null, q.user_id ?? null, q.year ?? null]
      )
      return rows
    }
  )

  // user_id dan pegawai_nama selalu diambil dari sesi login, bukan dari client.
  app.post<{ Body: DokumentasiBody }>(
    "/api/dokumentasi",
    { preHandler: auth.requireAuth, schema: { body: dokumentasiBody } },
    async (request) => {
      const user = currentUser(request)
      const b = request.body
      const { rows } = await db.query(
        `WITH inserted AS (
           INSERT INTO dokumentasi (user_id, pegawai_nama, proyek, tanggal_kegiatan, image_url, catatan, link)
           VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *
         )
         ${selectDokumentasi("inserted")}`,
        [user.id, user.nama, b.proyek.trim(), b.tanggal_kegiatan, b.image_url || null, b.catatan || null, b.link || null]
      )
      return rows[0]
    }
  )

  // Hanya pemilik yang boleh mengubah (admin pun tidak, sama seperti RLS lama).
  app.patch<{ Params: { id: string }; Body: DokumentasiBody }>(
    "/api/dokumentasi/:id",
    { preHandler: auth.requireAuth, schema: { params: idParams, body: dokumentasiBody } },
    async (request) => {
      const user = currentUser(request)
      const b = request.body
      await assertOwner(request.params.id, user.id, false)
      const { rows } = await db.query(
        `WITH updated AS (
           UPDATE dokumentasi
              SET proyek = $2, tanggal_kegiatan = $3, image_url = $4, catatan = $5, link = $6
            WHERE id = $1
            RETURNING *
         )
         ${selectDokumentasi("updated")}`,
        [request.params.id, b.proyek.trim(), b.tanggal_kegiatan, b.image_url || null, b.catatan || null, b.link || null]
      )
      return rows[0]
    }
  )

  // Pemilik atau admin boleh menghapus. Hanya disembunyikan (soft delete):
  // admin bisa melihat dan mengembalikannya; foto di Drive tidak disentuh.
  app.delete<{ Params: { id: string } }>(
    "/api/dokumentasi/:id",
    { preHandler: auth.requireAuth, schema: { params: idParams } },
    async (request) => {
      const user = currentUser(request)
      await assertOwner(request.params.id, user.id, user.role === "admin")
      await db.query(
        "UPDATE dokumentasi SET deleted_at = NOW(), deleted_by = $2 WHERE id = $1 AND deleted_at IS NULL",
        [request.params.id, user.id]
      )
      return { success: true }
    }
  )

  // Mengembalikan dokumentasi yang dihapus (admin saja).
  app.post<{ Params: { id: string } }>(
    "/api/dokumentasi/:id/restore",
    { preHandler: auth.requireAdmin, schema: { params: idParams } },
    async (request) => {
      const { rows } = await db.query(
        `WITH restored AS (
           UPDATE dokumentasi
              SET deleted_at = NULL, deleted_by = NULL
            WHERE id = $1 AND deleted_at IS NOT NULL
            RETURNING *
         )
         ${selectDokumentasi("restored")}`,
        [request.params.id]
      )
      if (!rows[0]) throw notFound("Dokumentasi yang dihapus tidak ditemukan.")
      return rows[0]
    }
  )

  // Dokumentasi yang sudah dihapus dianggap tidak ada (tidak bisa diubah/dihapus lagi).
  async function assertOwner(id: string, userId: string, isAdmin: boolean) {
    const { rows } = await db.query<{ user_id: string }>(
      "SELECT user_id FROM dokumentasi WHERE id = $1 AND deleted_at IS NULL",
      [id]
    )
    if (!rows[0]) throw notFound("Dokumentasi tidak ditemukan.")
    if (!isAdmin && rows[0].user_id !== userId) throw forbidden("Hanya pemilik yang dapat mengubah dokumentasi ini.")
  }
}
