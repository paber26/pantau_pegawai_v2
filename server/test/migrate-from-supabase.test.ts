import { readFileSync } from "node:fs"

import bcrypt from "bcryptjs"
import pg from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { migrateFromSupabase, rewriteImageUrl } from "../scripts/migrate-from-supabase.js"
import { buildApp } from "../src/app.js"
import type { Db } from "../src/db.js"
import { login, PUBLIC_API_URL, resetDatabase, testConfig } from "./helpers.js"

/**
 * Membuat database "Supabase tiruan": skema auth minimal + migration Supabase
 * lama dari repo (supabase/migrations/*.sql) dijalankan apa adanya.
 */
const FAKE_SUPABASE_URL = (process.env.TEST_DATABASE_URL ?? "postgres://postgres@localhost:5433/pantau_test").replace(
  /\/[^/]+$/,
  "/fake_supabase"
)
const SUPABASE_PROXY = "https://glywzqbifjordhwulpbw.supabase.co/functions/v1/image-proxy?id="

const supabaseHash = async (password: string) => (await bcrypt.hash(password, 10)).replace(/^\$2b\$/, "$2a$")

let target: Db
let source: pg.Client

async function createFakeSupabase() {
  const admin = new pg.Client({ connectionString: FAKE_SUPABASE_URL.replace(/\/[^/]+$/, "/postgres") })
  await admin.connect()
  await admin.query("DROP DATABASE IF EXISTS fake_supabase WITH (FORCE)")
  await admin.query("CREATE DATABASE fake_supabase")
  await admin.end()

  source = new pg.Client({ connectionString: FAKE_SUPABASE_URL })
  await source.connect()
  await source.query(`
    CREATE SCHEMA auth;
    CREATE TABLE auth.users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT,
      encrypted_password VARCHAR(255),
      raw_user_meta_data JSONB
    );
    CREATE FUNCTION auth.uid() RETURNS UUID LANGUAGE sql AS 'SELECT NULL::uuid';
    CREATE FUNCTION auth.role() RETURNS TEXT LANGUAGE sql AS 'SELECT NULL::text';
  `)
  for (const file of ["001_initial_schema.sql", "002_dokumentasi_harian.sql"]) {
    await source.query(readFileSync(new URL(`../../supabase/migrations/${file}`, import.meta.url), "utf8"))
  }

  // Trigger handle_new_user membuat profil public.users otomatis.
  const addAuthUser = async (email: string, password: string | null, meta: object) => {
    const { rows } = await source.query(
      "INSERT INTO auth.users (email, encrypted_password, raw_user_meta_data) VALUES ($1, $2, $3) RETURNING id",
      [email, password === null ? "" : await supabaseHash(password), JSON.stringify(meta)]
    )
    return rows[0].id as string
  }
  const adminId = await addAuthUser("admin@bps.go.id", "adminLama", { nama: "Administrator", role: "admin" })
  const budiId = await addAuthUser("budi@bps.go.id", "budiLama", { nama: "Budi Santoso" })
  await addAuthUser("tanpa.password@bps.go.id", null, { nama: "Tanpa Password" })
  const yatimId = await addAuthUser("yatim@bps.go.id", "x123456", {})
  await source.query("DELETE FROM public.users WHERE id = $1", [yatimId])
  await source.query("UPDATE public.users SET jabatan = 'Statistisi', unit_kerja = 'IPDS' WHERE id = $1", [budiId])

  const { rows: k } = await source.query(
    "INSERT INTO public.kegiatan (judul, deadline) VALUES ('Sakernas', '2026-08-31') RETURNING id"
  )
  await source.query("INSERT INTO public.penugasan (user_id, kegiatan_id) VALUES ($1, $2)", [budiId, k[0].id])
  await source.query("INSERT INTO public.laporan (user_id, kegiatan_id, image_url) VALUES ($1, $2, $3)", [
    budiId,
    k[0].id,
    `${SUPABASE_PROXY}laporanFile123`
  ])
  await source.query(
    `INSERT INTO public.dokumentasi (user_id, pegawai_nama, proyek, tanggal_kegiatan, image_url, link, catatan, created_at)
     VALUES ($1, 'Budi Santoso', 'Sakernas', '2026-05-04', $2, $2, 'Upload aplikasi', '2026-05-04 09:15:30.123456+08'),
            ($1, NULL, 'Podes', '2026-04-30', $3, $3, 'Data AppSheet', NULL)`,
    [budiId, `${SUPABASE_PROXY}fileBaru123456`, "https://drive.google.com/file/d/fileLamaAppSheet/view?usp=drivesdk"]
  )
  return { adminId, budiId }
}

const run = (extra: Partial<Parameters<typeof migrateFromSupabase>[0]> = {}) =>
  migrateFromSupabase({
    source: { connectionString: FAKE_SUPABASE_URL },
    target: { connectionString: testConfig().databaseUrl },
    publicApiUrl: PUBLIC_API_URL,
    log: () => {},
    ...extra
  })

let ids: { adminId: string; budiId: string }

beforeAll(async () => {
  target = await resetDatabase()
  ids = await createFakeSupabase()
})
afterAll(async () => {
  await source.end()
  await target.end()
})

describe("migrate-from-supabase", () => {
  it("dry run tidak menyimpan apa pun", async () => {
    const report = await run({ dryRun: true })
    expect(report.counts.dokumentasi).toEqual({ source: 2, target: 2 })
    const { rows } = await target.query("SELECT COUNT(*)::int AS n FROM users")
    expect(rows[0].n).toBe(0)
  })

  it("menyalin semua data, melaporkan user tanpa password & akun tanpa profil", async () => {
    const report = await run()
    expect(report.counts).toEqual({
      users: { source: 3, target: 3 },
      kegiatan: { source: 1, target: 1 },
      penugasan: { source: 1, target: 1 },
      laporan: { source: 1, target: 1 },
      dokumentasi: { source: 2, target: 2 }
    })
    expect(report.usersWithoutPassword).toEqual(["tanpa.password@bps.go.id"])
    expect(report.authUsersWithoutProfile).toEqual(["yatim@bps.go.id"])
    expect(report.rewrittenImageUrls).toBe(3)
  })

  it("UUID, role, tanggal & created_at sama persis; URL gambar Supabase diganti", async () => {
    const { rows: users } = await target.query("SELECT id, role, jabatan FROM users ORDER BY email")
    expect(users[0]).toEqual({ id: ids.adminId, role: "admin", jabatan: null })

    const { rows: docs } = await target.query(
      "SELECT proyek, tanggal_kegiatan, image_url, link, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') AS created FROM dokumentasi ORDER BY proyek"
    )
    expect(docs[1]).toEqual({
      proyek: "Sakernas",
      tanggal_kegiatan: "2026-05-04",
      image_url: `${PUBLIC_API_URL}/api/images?id=fileBaru123456`,
      link: `${PUBLIC_API_URL}/api/images?id=fileBaru123456`,
      created: "2026-05-04 01:15:30.123456"
    })
    // URL Drive lama dari AppSheet dibiarkan; created_at kosong diisi.
    expect(docs[0].image_url).toBe("https://drive.google.com/file/d/fileLamaAppSheet/view?usp=drivesdk")
    expect(docs[0].created).toBeTruthy()

    const { rows: laporan } = await target.query("SELECT image_url FROM laporan")
    expect(laporan[0].image_url).toBe(`${PUBLIC_API_URL}/api/images?id=laporanFile123`)
  })

  it("password lama tetap bisa dipakai login di API baru", async () => {
    const app = await buildApp({ config: testConfig(), db: target, drive: null })
    expect(await login(app, "budi@bps.go.id", "budiLama")).toBeTruthy()
    expect(await login(app, "admin@bps.go.id", "adminLama")).toBeTruthy()
    await expect(login(app, "tanpa.password@bps.go.id", "")).rejects.toThrow()
    await app.close()
  })

  it("menolak menimpa database berisi tanpa --force; --force mengulang dari awal", async () => {
    await expect(run()).rejects.toThrow(/--force/)
    const report = await run({ force: true })
    expect(report.counts.users).toEqual({ source: 3, target: 3 })
  })

  it("berhenti bila skema Supabase punya kolom yang tidak dikenal", async () => {
    await source.query("ALTER TABLE public.laporan ADD COLUMN catatan TEXT")
    await expect(run({ force: true, dryRun: true })).rejects.toThrow(/laporan.*catatan/)
    const report = await run({ force: true, dryRun: true, ignoreExtraColumns: true })
    expect(report.counts.laporan.target).toBe(1)
  })

  it("rewriteImageUrl", () => {
    expect(rewriteImageUrl(`${SUPABASE_PROXY}abc`, "https://api.x")).toBe("https://api.x/api/images?id=abc")
    expect(rewriteImageUrl("https://drive.google.com/open?id=abc", "https://api.x")).toBe(
      "https://drive.google.com/open?id=abc"
    )
    expect(rewriteImageUrl(null, "https://api.x")).toBeNull()
  })
})
