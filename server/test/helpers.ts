import { Readable } from "node:stream"

import bcrypt from "bcryptjs"
import type { FastifyInstance } from "fastify"
import pg from "pg"

import { buildApp } from "../src/app.js"
import type { Config } from "../src/config.js"
import { createPool, type Db } from "../src/db.js"
import type { DriveImage, DriveService } from "../src/drive.js"
import { runMigrations } from "../src/migrate.js"

/**
 * Test memakai PostgreSQL sungguhan. Atur TEST_DATABASE_URL bila perlu;
 * database-nya dibuat ulang (DROP + CREATE) setiap file test.
 */
const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL ?? "postgres://postgres@localhost:5433/pantau_test"

export const PUBLIC_API_URL = "https://api.contoh.go.id"

export async function resetDatabase(url = TEST_DATABASE_URL): Promise<Db> {
  const target = new URL(url)
  const dbName = target.pathname.slice(1)
  const admin = new URL(url)
  admin.pathname = "/postgres"
  const client = new pg.Client({ connectionString: admin.toString() })
  await client.connect()
  await client.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`)
  await client.query(`CREATE DATABASE ${dbName}`)
  await client.end()

  const db = createPool(url)
  await runMigrations(db, () => {})
  return db
}

export function testConfig(overrides: Partial<Config> = {}): Config {
  return {
    port: 0,
    databaseUrl: TEST_DATABASE_URL,
    publicApiUrl: PUBLIC_API_URL,
    corsOrigins: ["https://pantau.vercel.app", "http://localhost:*"],
    sessionTtlDays: 30,
    appTimezone: "Asia/Makassar",
    googleServiceAccountFile: null,
    googleDriveRootFolderId: null,
    ...overrides
  }
}

/** Pengganti Google Drive untuk test: menyimpan file di memori. */
export class FakeDrive implements DriveService {
  files = new Map<string, { bytes: Buffer; mimeType: string; folderPath: string[]; filename: string }>()
  private counter = 0

  async uploadFile(params: { bytes: Buffer; filename: string; mimeType: string; folderPath: string[] }) {
    const id = `fakeFileId${String(++this.counter).padStart(6, "0")}`
    this.files.set(id, params)
    return id
  }

  async getImage(fileId: string): Promise<DriveImage | null> {
    const file = this.files.get(fileId)
    if (!file || !file.mimeType.startsWith("image/")) return null
    return { stream: Readable.from(file.bytes), contentType: file.mimeType, contentLength: String(file.bytes.length) }
  }
}

export interface TestEnv {
  app: FastifyInstance
  db: Db
  drive: FakeDrive
}

export async function setup(options: { drive?: boolean } = {}): Promise<TestEnv> {
  const db = await resetDatabase()
  const drive = new FakeDrive()
  const app = await buildApp({ config: testConfig(), db, drive: options.drive === false ? null : drive })
  return { app, db, drive }
}

export async function teardown(env: TestEnv) {
  await env.app.close()
  await env.db.end()
}

/**
 * Buat user langsung di database. Hash dibuat dengan prefix `$2a$` seperti
 * hash dari Supabase Auth (GoTrue), untuk memastikan password lama tetap valid.
 */
export async function createUser(
  db: Db,
  user: { nama: string; email: string; password?: string | null; role?: "admin" | "pegawai"; jabatan?: string }
): Promise<string> {
  const hash =
    user.password === null ? null : (await bcrypt.hash(user.password ?? "rahasia123", 10)).replace(/^\$2b\$/, "$2a$")
  const { rows } = await db.query(
    `INSERT INTO users (nama, email, role, jabatan, password_hash) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
    [user.nama, user.email, user.role ?? "pegawai", user.jabatan ?? null, hash]
  )
  return rows[0].id
}

export async function login(app: FastifyInstance, email: string, password = "rahasia123"): Promise<string> {
  const res = await app.inject({ method: "POST", url: "/api/auth/login", payload: { email, password } })
  if (res.statusCode !== 200) throw new Error(`Login gagal (${res.statusCode}): ${res.body}`)
  return res.json().token
}

export const bearer = (token: string) => ({ authorization: `Bearer ${token}` })

/** Admin + dua pegawai yang sudah login. */
export async function seedUsers(env: TestEnv) {
  const adminId = await createUser(env.db, { nama: "Admin Sistem", email: "admin@bps.go.id", role: "admin" })
  const budiId = await createUser(env.db, { nama: "Budi Santoso", email: "budi@bps.go.id", jabatan: "Statistisi" })
  const sitiId = await createUser(env.db, { nama: "Siti Aminah", email: "siti@bps.go.id" })
  return {
    adminId,
    budiId,
    sitiId,
    admin: await login(env.app, "admin@bps.go.id"),
    budi: await login(env.app, "budi@bps.go.id"),
    siti: await login(env.app, "siti@bps.go.id")
  }
}

/** Bentuk body multipart untuk app.inject(). */
export async function multipartBody(form: FormData): Promise<{ payload: Buffer; headers: Record<string, string> }> {
  const res = new Response(form)
  return {
    payload: Buffer.from(await res.arrayBuffer()),
    headers: { "content-type": res.headers.get("content-type")! }
  }
}
