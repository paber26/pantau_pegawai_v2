/**
 * Login berbasis token sesi (opaque).
 *
 * Token acak 32 byte dikirim ke client; database hanya menyimpan hash SHA-256
 * dari token tersebut. Sesi berlaku `sessionTtlDays` hari dan diperpanjang
 * otomatis selama masih dipakai. Logout / reset password / hapus user cukup
 * menghapus baris di tabel `sessions`.
 */
import { createHash, randomBytes } from "node:crypto"

import bcrypt from "bcryptjs"
import type { FastifyRequest } from "fastify"

import type { Db, Queryable } from "./db.js"
import { forbidden, unauthorized } from "./errors.js"

export interface AuthUser {
  id: string
  nama: string
  email: string
  role: "admin" | "pegawai"
  sessionId: string
}

declare module "fastify" {
  interface FastifyRequest {
    user?: AuthUser
  }
}

/** Kolom profil user yang boleh dikirim ke client (tanpa password_hash). */
export const USER_COLUMNS = "id, nama, email, jabatan, unit_kerja, role, created_at"

export const MIN_PASSWORD_LENGTH = 6

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex")
}

export function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10)
}

/**
 * Cek password terhadap hash bcrypt. Hash dari Supabase (`$2a$10$...`) juga
 * didukung, sehingga password lama tetap berlaku setelah migrasi.
 */
export async function verifyPassword(password: string, hash: string | null): Promise<boolean> {
  if (!hash) return false
  try {
    return await bcrypt.compare(password, hash)
  } catch {
    return false
  }
}

export async function createSession(db: Queryable, userId: string, ttlDays: number): Promise<string> {
  const token = randomBytes(32).toString("base64url")
  await db.query(
    `INSERT INTO sessions (user_id, token_hash, expires_at)
     VALUES ($1, $2, NOW() + make_interval(days => $3))`,
    [userId, hashToken(token), ttlDays]
  )
  return token
}

export async function deleteSessionsOfUser(db: Queryable, userId: string): Promise<void> {
  await db.query("DELETE FROM sessions WHERE user_id = $1", [userId])
}

function bearerToken(request: FastifyRequest): string | null {
  const header = request.headers.authorization
  if (!header) return null
  const match = /^Bearer\s+(.+)$/i.exec(header)
  return match ? match[1].trim() : null
}

/** Membuat hook `requireAuth` dan `requireAdmin` untuk dipasang di route. */
export function authHooks(db: Db, ttlDays: number) {
  async function requireAuth(request: FastifyRequest) {
    const token = bearerToken(request)
    if (!token) throw unauthorized()

    const { rows } = await db.query<AuthUser & { last_used_at: Date }>(
      `SELECT u.id, u.nama, u.email, u.role, s.id AS "sessionId", s.last_used_at
         FROM sessions s
         JOIN users u ON u.id = s.user_id
        WHERE s.token_hash = $1 AND s.expires_at > NOW()`,
      [hashToken(token)]
    )
    const row = rows[0]
    if (!row) throw unauthorized()

    // Perpanjang sesi paling sering sekali per jam agar tidak menulis ke DB
    // di setiap request.
    if (Date.now() - row.last_used_at.getTime() > 60 * 60 * 1000) {
      await db.query(
        `UPDATE sessions
            SET last_used_at = NOW(), expires_at = NOW() + make_interval(days => $2)
          WHERE id = $1`,
        [row.sessionId, ttlDays]
      )
    }

    request.user = { id: row.id, nama: row.nama, email: row.email, role: row.role, sessionId: row.sessionId }
  }

  async function requireAdmin(request: FastifyRequest) {
    await requireAuth(request)
    if (request.user!.role !== "admin") throw forbidden("Hanya admin yang dapat melakukan aksi ini.")
  }

  return { requireAuth, requireAdmin }
}

export type AuthHooks = ReturnType<typeof authHooks>

/** Ambil user yang sudah diverifikasi oleh `requireAuth`. */
export function currentUser(request: FastifyRequest): AuthUser {
  if (!request.user) throw unauthorized()
  return request.user
}
