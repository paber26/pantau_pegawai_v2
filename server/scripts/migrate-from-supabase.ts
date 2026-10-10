/**
 * Pindahkan semua data dari database Supabase lama ke PostgreSQL baru di VPS.
 *
 * - Menyalin users, kegiatan, penugasan, laporan, dokumentasi dengan UUID dan
 *   created_at yang sama.
 * - Password lama tetap berlaku: hash bcrypt diambil dari auth.users.encrypted_password.
 * - URL gambar lama (https://<project>.supabase.co/functions/v1/image-proxy?id=...)
 *   diganti menjadi ${PUBLIC_API_URL}/api/images?id=...
 *
 * Pemakaian (dari folder server/, atau di container: docker compose exec api ...):
 *
 *   SUPABASE_DB_URL="postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres" \
 *   DATABASE_URL="postgres://pantau:<password>@db:5432/pantau" \
 *   PUBLIC_API_URL="https://api.domain-anda.go.id" \
 *   node dist/scripts/migrate-from-supabase.js [--dry-run] [--force] [--ignore-extra-columns]
 *
 *   --dry-run               jalankan semuanya lalu ROLLBACK (tidak ada yang tersimpan)
 *   --force                 kosongkan database tujuan dulu bila sudah berisi
 *   --ignore-extra-columns  lanjutkan walau tabel Supabase punya kolom yang tidak dikenal
 *
 * SUPABASE_CA_CERT (opsional): path sertifikat CA Supabase untuk verifikasi SSL penuh.
 */
import { readFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import pg from "pg"

// Simpan timestamp & tanggal persis seperti di sumber (presisi mikrodetik).
pg.types.setTypeParser(pg.types.builtins.TIMESTAMPTZ, (v) => v)
pg.types.setTypeParser(pg.types.builtins.TIMESTAMP, (v) => v)
pg.types.setTypeParser(pg.types.builtins.DATE, (v) => v)

/** Kolom yang disalin per tabel, urut sesuai dependensi foreign key. */
export const TABLES: Record<string, string[]> = {
  users: ["id", "nama", "email", "jabatan", "unit_kerja", "role", "created_at"],
  kegiatan: ["id", "judul", "deskripsi", "deadline", "created_at"],
  penugasan: ["id", "user_id", "kegiatan_id", "created_at"],
  laporan: ["id", "user_id", "kegiatan_id", "image_url", "deskripsi", "created_at"],
  dokumentasi: [
    "id",
    "user_id",
    "pegawai_nama",
    "proyek",
    "tanggal_kegiatan",
    "image_url",
    "catatan",
    "link",
    "created_at"
  ]
}

const SUPABASE_PROXY_URL = /^https?:\/\/[^/]+\/functions\/v1\/image-proxy\?id=/

export interface MigrateOptions {
  source: pg.ClientConfig
  target: pg.ClientConfig
  publicApiUrl: string
  force?: boolean
  dryRun?: boolean
  ignoreExtraColumns?: boolean
  log?: (msg: string) => void
}

export interface MigrateReport {
  counts: Record<string, { source: number; target: number }>
  usersWithoutPassword: string[]
  authUsersWithoutProfile: string[]
  rewrittenImageUrls: number
}

type Row = Record<string, unknown>

export function rewriteImageUrl(url: unknown, publicApiUrl: string): unknown {
  if (typeof url !== "string") return url
  return url.replace(SUPABASE_PROXY_URL, `${publicApiUrl}/api/images?id=`)
}

export async function migrateFromSupabase(opts: MigrateOptions): Promise<MigrateReport> {
  const log = opts.log ?? console.log
  const source = new pg.Client(opts.source)
  const target = new pg.Client(opts.target)
  await source.connect()
  await target.connect()

  try {
    // ── 1. Baca semua data sumber dalam satu snapshot yang konsisten ──────
    await source.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")

    const { rows: columnRows } = await source.query<{ table_name: string; column_name: string }>(
      `SELECT table_name, column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = ANY($1)`,
      [Object.keys(TABLES)]
    )
    const problems: string[] = []
    for (const [table, columns] of Object.entries(TABLES)) {
      const actual = columnRows.filter((r) => r.table_name === table).map((r) => r.column_name)
      if (actual.length === 0) {
        problems.push(`Tabel public.${table} tidak ditemukan di Supabase.`)
        continue
      }
      const missing = columns.filter((c) => !actual.includes(c) && c !== "pegawai_nama")
      const extra = actual.filter((c) => !columns.includes(c))
      if (missing.length) problems.push(`public.${table}: kolom tidak ada di Supabase: ${missing.join(", ")}`)
      if (extra.length && !opts.ignoreExtraColumns) {
        problems.push(
          `public.${table}: kolom tambahan di Supabase akan hilang: ${extra.join(", ")} (pakai --ignore-extra-columns bila memang tidak dipakai)`
        )
      }
    }
    if (problems.length) throw new Error(`Skema Supabase berbeda dari yang diharapkan:\n- ${problems.join("\n- ")}`)

    const data: Record<string, Row[]> = {}
    for (const [table, columns] of Object.entries(TABLES)) {
      const present = columnRows.filter((r) => r.table_name === table).map((r) => r.column_name)
      const select = columns.map((c) => (present.includes(c) ? c : `NULL AS ${c}`)).join(", ")
      data[table] = (await source.query(`SELECT ${select} FROM public.${table} ORDER BY created_at NULLS FIRST, id`)).rows
    }
    const { rows: authUsers } = await source.query<{ id: string; email: string | null; encrypted_password: string | null }>(
      "SELECT id, email, encrypted_password FROM auth.users"
    )
    await source.query("COMMIT")

    // ── 2. Gabungkan hash password dari auth.users ke profil users ─────────
    const authById = new Map(authUsers.map((u) => [u.id, u]))
    const authByEmail = new Map(authUsers.filter((u) => u.email).map((u) => [u.email!.toLowerCase(), u]))
    const profileIds = new Set(data.users.map((u) => u.id as string))
    const report: MigrateReport = {
      counts: {},
      usersWithoutPassword: [],
      authUsersWithoutProfile: authUsers.filter((u) => !profileIds.has(u.id)).map((u) => u.email ?? u.id),
      rewrittenImageUrls: 0
    }

    const now = new Date().toISOString()
    data.users = data.users.map((u) => {
      const authUser = authById.get(u.id as string) ?? authByEmail.get(String(u.email).toLowerCase())
      const hash = authUser?.encrypted_password?.trim() || null
      if (!hash) report.usersWithoutPassword.push(String(u.email))
      return { ...u, password_hash: hash }
    })
    for (const rows of Object.values(data)) {
      for (const row of rows) row.created_at ??= now
    }
    for (const row of [...data.dokumentasi, ...data.laporan]) {
      for (const key of ["image_url", "link"]) {
        if (!(key in row)) continue
        const rewritten = rewriteImageUrl(row[key], opts.publicApiUrl)
        if (rewritten !== row[key]) report.rewrittenImageUrls++
        row[key] = rewritten
      }
    }

    // ── 3. Tulis ke database tujuan dalam satu transaksi ──────────────────
    await target.query("BEGIN")
    const { rows: existing } = await target.query<{ n: number }>(
      `SELECT ${Object.keys(TABLES)
        .map((t) => `(SELECT COUNT(*) FROM ${t})`)
        .join(" + ")}::int AS n`
    )
    if (existing[0].n > 0) {
      if (!opts.force) {
        throw new Error(
          `Database tujuan sudah berisi ${existing[0].n} baris. Jalankan dengan --force untuk mengosongkannya dulu.`
        )
      }
      log("--force: mengosongkan database tujuan...")
      await target.query(`TRUNCATE ${Object.keys(TABLES).join(", ")}, sessions CASCADE`)
    }

    for (const [table, rows] of Object.entries(data)) {
      for (let i = 0; i < rows.length; i += 1000) {
        const batch = rows.slice(i, i + 1000)
        await target.query(`INSERT INTO ${table} SELECT * FROM json_populate_recordset(NULL::${table}, $1::json)`, [
          JSON.stringify(batch)
        ])
      }
      const { rows: countRows } = await target.query<{ n: number }>(`SELECT COUNT(*)::int AS n FROM ${table}`)
      report.counts[table] = { source: rows.length, target: countRows[0].n }
    }

    if (opts.dryRun) {
      await target.query("ROLLBACK")
      log("--dry-run: semua perubahan dibatalkan (ROLLBACK).")
    } else {
      await target.query("COMMIT")
    }
    return report
  } catch (err) {
    await target.query("ROLLBACK").catch(() => {})
    throw err
  } finally {
    await source.end()
    await target.end()
  }
}

/** Konfigurasi koneksi Supabase: SSL wajib; verifikasi CA bila SUPABASE_CA_CERT diisi. */
function supabaseClientConfig(url: string): pg.ClientConfig {
  const parsed = new URL(url)
  parsed.searchParams.delete("sslmode")
  const caFile = process.env.SUPABASE_CA_CERT
  return {
    connectionString: parsed.toString(),
    ssl: caFile ? { ca: readFileSync(caFile, "utf8") } : { rejectUnauthorized: false }
  }
}

function printReport(report: MigrateReport) {
  console.log("\nJumlah baris (Supabase → VPS):")
  for (const [table, c] of Object.entries(report.counts)) {
    console.log(`  ${table.padEnd(12)} ${String(c.source).padStart(7)} → ${String(c.target).padStart(7)}${c.source === c.target ? "" : "  ⚠ BEDA"}`)
  }
  console.log(`\nURL gambar yang diganti ke API baru: ${report.rewrittenImageUrls}`)
  if (report.usersWithoutPassword.length) {
    console.log(`\n⚠ ${report.usersWithoutPassword.length} user tanpa password (perlu reset oleh admin):`)
    for (const email of report.usersWithoutPassword) console.log(`  - ${email}`)
  }
  if (report.authUsersWithoutProfile.length) {
    console.log(`\n⚠ ${report.authUsersWithoutProfile.length} akun auth tanpa profil di public.users (dilewati):`)
    for (const email of report.authUsersWithoutProfile) console.log(`  - ${email}`)
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const args = new Set(process.argv.slice(2))
  const missing = ["SUPABASE_DB_URL", "DATABASE_URL", "PUBLIC_API_URL"].filter((k) => !process.env[k])
  if (missing.length) {
    console.error(`Environment variable belum diset: ${missing.join(", ")}`)
    process.exit(1)
  }
  migrateFromSupabase({
    source: supabaseClientConfig(process.env.SUPABASE_DB_URL!),
    target: { connectionString: process.env.DATABASE_URL },
    publicApiUrl: process.env.PUBLIC_API_URL!.replace(/\/+$/, ""),
    force: args.has("--force"),
    dryRun: args.has("--dry-run"),
    ignoreExtraColumns: args.has("--ignore-extra-columns")
  })
    .then((report) => {
      printReport(report)
      console.log(args.has("--dry-run") ? "\nDry run selesai." : "\n✅ Migrasi selesai.")
    })
    .catch((err) => {
      console.error(`\n❌ Migrasi gagal: ${err.message}`)
      process.exitCode = 1
    })
}
