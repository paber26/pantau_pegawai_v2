/**
 * Runner migrasi skema sederhana.
 *
 * Menjalankan file `migrations/NNN_*.sql` yang belum tercatat di tabel
 * `schema_migrations`, berurutan, masing-masing dalam satu transaksi.
 * Dipanggil otomatis saat API start (src/server.ts) dan bisa dijalankan manual:
 *   npm run migrate
 */
import { readdir, readFile } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

import { createPool, withTransaction, type Db } from "./db.js"

const MIGRATIONS_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../migrations")

// Ketika di-build, file ini ada di dist/src/, sedangkan folder migrations ada
// di root package. Cari ke atas sampai ketemu.
async function findMigrationsDir(): Promise<string> {
  for (const dir of [MIGRATIONS_DIR, path.resolve(MIGRATIONS_DIR, "../../migrations")]) {
    try {
      await readdir(dir)
      return dir
    } catch {
      // coba kandidat berikutnya
    }
  }
  throw new Error("Folder migrations tidak ditemukan")
}

export async function runMigrations(db: Db, log: (msg: string) => void = console.log): Promise<string[]> {
  const dir = await findMigrationsDir()
  const files = (await readdir(dir)).filter((f) => /^\d+_.+\.sql$/.test(f)).sort()

  await db.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `)

  const applied: string[] = []
  for (const file of files) {
    const sql = await readFile(path.join(dir, file), "utf8")
    const ran = await withTransaction(db, async (client) => {
      // Kunci agar dua instance API yang start bersamaan tidak menjalankan
      // migrasi yang sama dua kali.
      await client.query("SELECT pg_advisory_xact_lock(727274)")
      const { rowCount } = await client.query("SELECT 1 FROM schema_migrations WHERE name = $1", [file])
      if (rowCount) return false
      await client.query(sql)
      await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file])
      return true
    })
    if (ran) {
      log(`Migrasi dijalankan: ${file}`)
      applied.push(file)
    }
  }
  return applied
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const url = process.env.DATABASE_URL
  if (!url) {
    console.error("DATABASE_URL belum diset")
    process.exit(1)
  }
  const db = createPool(url)
  runMigrations(db)
    .then((applied) => console.log(applied.length ? "Selesai." : "Tidak ada migrasi baru."))
    .catch((err) => {
      console.error(err)
      process.exitCode = 1
    })
    .finally(() => db.end())
}
