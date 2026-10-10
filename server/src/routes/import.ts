/**
 * Import data dari Google Sheets (pengganti Edge Function `import-from-sheets`).
 *
 * Body: { targetTable, rows: [{ kolom: nilai }] } — dikirim per batch oleh aplikasi.
 * Setiap baris disimpan terpisah, sehingga satu baris gagal tidak
 * menggagalkan baris lain dalam batch yang sama.
 */
import type { FastifyInstance } from "fastify"

import type { AppContext } from "../app.js"
import { normalizeDate } from "../dates.js"
import { badRequest, pgErrorMessage } from "../errors.js"

type ColumnType = "text" | "date" | "uuid"

interface ImportableTable {
  columns: Record<string, ColumnType>
  required: string[]
}

// Hanya tabel & kolom ini yang boleh diisi lewat import. Akun pegawai dibuat
// lewat menu Pegawai (perlu password), bukan dari spreadsheet.
const IMPORTABLE: Record<string, ImportableTable> = {
  kegiatan: {
    columns: { judul: "text", deskripsi: "text", deadline: "date" },
    required: ["judul", "deadline"]
  },
  dokumentasi: {
    columns: {
      user_id: "uuid",
      proyek: "text",
      tanggal_kegiatan: "date",
      catatan: "text",
      link: "text",
      image_url: "text"
    },
    required: ["user_id", "proyek", "tanggal_kegiatan"]
  }
}

interface ImportRowError {
  rowIndex: number
  data: Record<string, unknown>
  message: string
}

/** Ubah satu baris spreadsheet menjadi nilai kolom yang siap di-INSERT. */
function prepareRow(table: ImportableTable, row: Record<string, unknown>): Record<string, string | null> {
  const values: Record<string, string | null> = {}
  for (const [column, raw] of Object.entries(row)) {
    const type = table.columns[column]
    if (!type) throw new Error(`Kolom '${column}' tidak dikenal`)
    const text = raw === null || raw === undefined ? "" : String(raw).trim()
    if (text === "") {
      values[column] = null
    } else if (type === "date") {
      const date = normalizeDate(text)
      if (!date) throw new Error(`Format tanggal tidak valid pada kolom '${column}': ${text}`)
      values[column] = date
    } else {
      values[column] = text
    }
  }
  for (const column of table.required) {
    if (!values[column]) throw new Error(`Kolom '${column}' wajib diisi`)
  }
  return values
}

export async function importRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db, auth } = ctx

  app.post<{ Body: { targetTable: string; rows: Record<string, unknown>[] } }>(
    "/api/import",
    {
      preHandler: auth.requireAdmin,
      bodyLimit: 5 * 1024 * 1024,
      schema: {
        body: {
          type: "object",
          required: ["targetTable", "rows"],
          properties: {
            targetTable: { type: "string" },
            rows: { type: "array", minItems: 1, maxItems: 1000, items: { type: "object" } }
          }
        }
      }
    },
    async (request) => {
      const { targetTable, rows } = request.body
      const table = IMPORTABLE[targetTable]
      if (!table) {
        throw badRequest(`Import ke tabel '${targetTable}' tidak didukung. Tabel yang didukung: ${Object.keys(IMPORTABLE).join(", ")}`)
      }

      const errors: ImportRowError[] = []
      let imported = 0
      for (const [index, row] of rows.entries()) {
        try {
          const values = prepareRow(table, row)
          const columns = Object.keys(values)
          const params = columns.map((c) => values[c])
          const placeholders = columns.map((_, i) => `$${i + 1}`)
          if (targetTable === "dokumentasi") {
            // Isi pegawai_nama dari profil user, sama seperti input lewat aplikasi.
            columns.push("pegawai_nama")
            placeholders.push(`(SELECT nama FROM users WHERE id = $${columns.indexOf("user_id") + 1}::uuid)`)
          }
          // Nama kolom aman: hanya berasal dari whitelist IMPORTABLE.
          await db.query(
            `INSERT INTO ${targetTable} (${columns.join(", ")}) VALUES (${placeholders.join(", ")})`,
            params
          )
          imported++
        } catch (err) {
          const pg = pgErrorMessage(err as { code?: string })
          errors.push({ rowIndex: index, data: row, message: pg?.message ?? (err as Error).message })
        }
      }

      return { success: true, imported, failed: errors.length, errors }
    }
  )
}
