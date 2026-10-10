import type { FastifyError, FastifyReply, FastifyRequest } from "fastify"

/** Error dengan status HTTP; pesannya dikirim ke client sebagai `{ error }`. */
export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string
  ) {
    super(message)
  }
}

export const badRequest = (msg: string) => new HttpError(400, msg)
export const unauthorized = (msg = "Sesi tidak valid, silakan login ulang.") => new HttpError(401, msg)
export const forbidden = (msg = "Anda tidak punya akses untuk aksi ini.") => new HttpError(403, msg)
export const notFound = (msg = "Data tidak ditemukan.") => new HttpError(404, msg)

/** Pesan yang lebih ramah untuk error PostgreSQL yang umum. */
export function pgErrorMessage(err: {
  code?: string
  constraint?: string
  detail?: string
  message?: string
}): HttpError | null {
  switch (err.code) {
    case "23505": // unique_violation
      if (err.constraint === "users_email_lower_key") return new HttpError(409, "Email sudah terdaftar.")
      if (err.constraint === "penugasan_user_id_kegiatan_id_key") {
        return new HttpError(409, "Pegawai sudah ditugaskan ke kegiatan ini.")
      }
      return new HttpError(409, "Data sudah ada.")
    case "23503": // foreign_key_violation
      return badRequest("Data terkait tidak ditemukan.")
    case "23502": // not_null_violation
    case "23514": // check_violation
    case "22P02": // invalid_text_representation (mis. UUID tidak valid)
    case "22007": // invalid_datetime_format
    case "22008": // datetime_field_overflow
      return badRequest(`Data tidak valid: ${err.detail ?? err.message}`)
    default:
      return null
  }
}

export function errorHandler(err: FastifyError, request: FastifyRequest, reply: FastifyReply) {
  if (err instanceof HttpError) {
    return reply.status(err.statusCode).send({ error: err.message })
  }
  if (err.validation) {
    return reply.status(400).send({ error: `Input tidak valid: ${err.message}` })
  }
  const pgErr = pgErrorMessage(err as unknown as { code?: string })
  if (pgErr) {
    return reply.status(pgErr.statusCode).send({ error: pgErr.message })
  }
  if (err.statusCode && err.statusCode < 500) {
    return reply.status(err.statusCode).send({ error: err.message })
  }
  request.log.error(err)
  return reply.status(500).send({ error: "Terjadi kesalahan pada server." })
}
