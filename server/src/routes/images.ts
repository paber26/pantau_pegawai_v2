/**
 * Proxy gambar dari Google Drive (pengganti Edge Function `image-proxy`).
 *
 * GET /api/images?id=<driveFileId>
 *
 * Sama seperti sebelumnya, endpoint ini publik (tanpa login) agar gambar bisa
 * ditampilkan langsung oleh <img>/Image.network dan tidak "putih" saat sesi
 * habis. Foto di Drive memang sudah di-share "siapa pun yang punya link".
 * Hanya file bertipe image/* yang dilayani.
 */
import type { FastifyInstance } from "fastify"

import type { AppContext } from "../app.js"
import { HttpError, notFound } from "../errors.js"

const DRIVE_FILE_ID = "^[A-Za-z0-9_-]{10,200}$"

export async function imageRoutes(app: FastifyInstance, ctx: AppContext) {
  const { drive } = ctx

  app.get<{ Querystring: { id: string } }>(
    "/api/images",
    {
      config: { rateLimit: { max: 1200, timeWindow: "1 minute" } },
      schema: {
        querystring: {
          type: "object",
          required: ["id"],
          properties: { id: { type: "string", pattern: DRIVE_FILE_ID } }
        }
      }
    },
    async (request, reply) => {
      if (!drive) throw new HttpError(503, "Akses Google Drive belum dikonfigurasi di server.")
      const image = await drive.getImage(request.query.id)
      if (!image) throw notFound("Gambar tidak ditemukan.")

      reply
        .header("Content-Type", image.contentType)
        // Isi file Drive untuk satu ID tidak berubah → boleh di-cache lama.
        .header("Cache-Control", "public, max-age=2592000, immutable")
        .header("Cross-Origin-Resource-Policy", "cross-origin")
      if (image.contentLength) reply.header("Content-Length", image.contentLength)
      return reply.send(image.stream)
    }
  )
}
