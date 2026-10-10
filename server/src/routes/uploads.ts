/**
 * Upload foto ke Google Drive (pengganti Edge Function `upload-to-drive`).
 *
 * Multipart: file, tanggal (yyyy-MM-dd), filename.
 * Struktur folder: ROOT/{nama pegawai}/{tanggal}/{filename}
 * Nama folder pegawai diambil dari akun yang login, bukan dari input client.
 */
import type { FastifyInstance } from "fastify"

import { currentUser } from "../auth.js"
import type { AppContext } from "../app.js"
import { badRequest, HttpError } from "../errors.js"

export const imageUrlFor = (publicApiUrl: string, fileId: string) => `${publicApiUrl}/api/images?id=${fileId}`

export async function uploadRoutes(app: FastifyInstance, ctx: AppContext) {
  const { auth, drive, config } = ctx

  app.post("/api/uploads", { preHandler: auth.requireAuth }, async (request) => {
    if (!drive) throw new HttpError(503, "Upload foto belum dikonfigurasi di server.")
    if (!request.isMultipart()) throw badRequest("Request harus multipart/form-data.")

    const fields: Record<string, string> = {}
    let file: { bytes: Buffer; mimeType: string } | null = null
    for await (const part of request.parts()) {
      if (part.type === "file") {
        if (part.fieldname !== "file") {
          await part.toBuffer()
          continue
        }
        file = { bytes: await part.toBuffer(), mimeType: part.mimetype }
      } else {
        fields[part.fieldname] = String(part.value)
      }
    }

    if (!file || file.bytes.length === 0) throw badRequest("File foto tidak ada.")
    const tanggal = fields.tanggal ?? ""
    if (!/^\d{4}-\d{2}-\d{2}$/.test(tanggal)) throw badRequest("Parameter tanggal harus berformat yyyy-MM-dd.")

    // Client lama selalu mengirim foto_<timestamp>.jpg; tetap bersihkan nama file.
    const filename = (fields.filename ?? "").replace(/[\\/\u0000-\u001f]/g, "_").slice(0, 200) || `foto_${Date.now()}.jpg`
    const mimeType = file.mimeType.startsWith("image/") ? file.mimeType : "image/jpeg"

    const fileId = await drive.uploadFile({
      bytes: file.bytes,
      filename,
      mimeType,
      folderPath: [currentUser(request).nama, tanggal]
    })
    return { image_url: imageUrlFor(config.publicApiUrl, fileId), file_id: fileId }
  })
}
