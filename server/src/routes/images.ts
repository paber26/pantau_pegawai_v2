/**
 * Proxy gambar dari Google Drive (pengganti Edge Function `image-proxy`).
 *
 * GET /api/images?id=<driveFileId>         foto asli
 * GET /api/images/thumb?id=<driveFileId>   thumbnail kecil untuk daftar
 *
 * Thumbnail sengaja memakai path sendiri (bukan `?size=`): API versi lama
 * mengabaikan parameter yang tidak dikenal dan akan mengirim foto asli dengan
 * cache 30 hari, sedangkan path baru dijawab 404 sehingga aplikasi beralih ke
 * foto asli tanpa menyimpannya sebagai thumbnail.
 *
 * Sama seperti sebelumnya, endpoint ini publik (tanpa login) agar gambar bisa
 * ditampilkan langsung oleh <img>/Image.network dan tidak "putih" saat sesi
 * habis. Foto di Drive memang sudah di-share "siapa pun yang punya link".
 * Hanya file bertipe image/* yang dilayani.
 */
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify"

import type { AppContext } from "../app.js"
import type { DriveImage } from "../drive.js"
import { HttpError, notFound } from "../errors.js"

const DRIVE_FILE_ID = "^[A-Za-z0-9_-]{10,200}$"
/**
 * Sisi terpanjang thumbnail (px). Kartu daftar ±72 pt, jadi cukup tajam
 * sampai layar 4x; ukurannya biasanya puluhan KB, bukan ratusan KB.
 */
const THUMBNAIL_SIZE = 320
const CACHE_LONG = "public, max-age=2592000, immutable"

type ImageRequest = FastifyRequest<{ Querystring: { id: string } }>

export async function imageRoutes(app: FastifyInstance, ctx: AppContext) {
  const { drive } = ctx

  const options = {
    config: { rateLimit: { max: 1200, timeWindow: "1 minute" } },
    schema: {
      querystring: {
        type: "object",
        required: ["id"],
        properties: { id: { type: "string", pattern: DRIVE_FILE_ID } }
      }
    }
  }

  function send(reply: FastifyReply, image: DriveImage | null, cacheControl: string) {
    if (!image) throw notFound("Gambar tidak ditemukan.")
    reply
      .header("Content-Type", image.contentType)
      .header("Cache-Control", cacheControl)
      .header("Cross-Origin-Resource-Policy", "cross-origin")
    if (image.contentLength) reply.header("Content-Length", image.contentLength)
    return reply.send(image.stream)
  }

  function requireDrive() {
    if (!drive) throw new HttpError(503, "Akses Google Drive belum dikonfigurasi di server.")
    return drive
  }

  app.get("/api/images", options, async (request: ImageRequest, reply) => {
    // Isi file Drive untuk satu ID tidak berubah → boleh di-cache lama.
    return send(reply, await requireDrive().getImage(request.query.id), CACHE_LONG)
  })

  app.get("/api/images/thumb", options, async (request: ImageRequest, reply) => {
    const drive = requireDrive()
    const { id } = request.query
    let thumb: DriveImage | null = null
    try {
      thumb = await drive.getThumbnail(id, THUMBNAIL_SIZE)
    } catch (err) {
      request.log.warn({ err }, "Thumbnail Drive gagal diambil; memakai foto asli")
    }
    if (thumb) return send(reply, thumb, CACHE_LONG)
    // Thumbnail belum dibuat Drive (mis. foto baru diunggah): kirim foto asli,
    // tapi jangan di-cache lama agar berikutnya mendapat thumbnail.
    return send(reply, await drive.getImage(id), "public, max-age=600")
  })
}
