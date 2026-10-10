/**
 * Cleanup duplikat di tabel `dokumentasi`.
 *
 * Duplikat didefinisikan sebagai baris dengan kombinasi yang sama untuk
 * (user_id, tanggal_kegiatan, proyek). Untuk setiap kelompok duplikat,
 * baris dengan `created_at` paling lama dipertahankan; sisanya dihapus.
 *
 * Cara jalankan (dari folder server/):
 *   DATABASE_URL=postgres://... npx tsx scripts/cleanup-duplicates.ts
 *
 * Tambah --dry-run untuk hanya menampilkan apa yang akan dihapus tanpa
 * benar-benar menghapus.
 */

import pg from "pg"

pg.types.setTypeParser(pg.types.builtins.DATE, (v) => v)

const DATABASE_URL = process.env.DATABASE_URL ?? ""
const DRY_RUN = process.argv.includes("--dry-run")

if (!DATABASE_URL) {
  console.error("❌ Set DATABASE_URL terlebih dahulu")
  process.exit(1)
}

const db = new pg.Pool({ connectionString: DATABASE_URL })

interface DokRow {
  id: string
  user_id: string
  tanggal_kegiatan: string
  proyek: string
}

async function fetchAllDokumentasi(): Promise<DokRow[]> {
  const { rows } = await db.query<DokRow>(
    "SELECT id, user_id, tanggal_kegiatan, proyek FROM dokumentasi ORDER BY created_at ASC, id ASC"
  )
  return rows
}

async function main() {
  console.log("🧹 Cleanup duplikat dokumentasi...\n")
  if (DRY_RUN) console.log("⚠️  DRY RUN — tidak akan menghapus apapun\n")

  const allDok = await fetchAllDokumentasi()
  console.log(`📋 Total baris di DB: ${allDok.length}`)

  // Group by (user_id, tanggal_kegiatan, proyek)
  const groups = new Map<string, DokRow[]>()
  for (const dok of allDok) {
    const key = `${dok.user_id}|${dok.tanggal_kegiatan}|${dok.proyek}`
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key)!.push(dok)
  }

  // Cari kelompok yang punya duplikat (>1 baris)
  const duplicateGroups: { key: string; totalRows: number; kept: string; deleted: string[] }[] = []
  const idsToDelete: string[] = []
  for (const [key, rows] of groups.entries()) {
    if (rows.length > 1) {
      // Sudah di-sort by created_at ASC, jadi rows[0] adalah yang paling lama (keep).
      // Sisanya (rows[1..]) adalah duplikat yang akan dihapus.
      duplicateGroups.push({ key, totalRows: rows.length, kept: rows[0].id, deleted: rows.slice(1).map((r) => r.id) })
      idsToDelete.push(...rows.slice(1).map((r) => r.id))
    }
  }

  console.log(`📊 Kelompok duplikat ditemukan: ${duplicateGroups.length}`)
  console.log(`🗑️  Total baris akan dihapus  : ${idsToDelete.length}`)
  console.log(`✅ Total baris akan disimpan  : ${allDok.length - idsToDelete.length}`)

  if (duplicateGroups.length === 0) {
    console.log("\n✅ Tidak ada duplikat. Selesai.")
    return
  }

  if (DRY_RUN) {
    console.log("\n10 contoh duplikat yang akan dihapus:")
    duplicateGroups.slice(0, 10).forEach((g) => {
      console.log(`  - ${g.key}: ${g.totalRows} baris (keep ${g.kept}, hapus ${g.deleted.length})`)
    })
    console.log("\n⚠️  Dry run selesai — tidak ada perubahan.")
    return
  }

  // Hapus dalam batch
  const BATCH = 200
  let deleted = 0
  for (let i = 0; i < idsToDelete.length; i += BATCH) {
    const chunk = idsToDelete.slice(i, i + BATCH)
    const batchNum = Math.floor(i / BATCH) + 1
    const totalBatch = Math.ceil(idsToDelete.length / BATCH)
    process.stdout.write(`   Batch ${batchNum}/${totalBatch}... `)

    try {
      await db.query("DELETE FROM dokumentasi WHERE id = ANY($1::uuid[])", [chunk])
    } catch (error) {
      const message = (error as Error).message
      console.log(`❌ ${message}`)
      throw new Error(`Batch ${batchNum} gagal: ${message}`)
    }
    deleted += chunk.length
    console.log(`✅ ${deleted}/${idsToDelete.length}`)
  }

  console.log("\n" + "=".repeat(50))
  console.log("📊 LAPORAN CLEANUP")
  console.log("=".repeat(50))
  console.log(`✅ Berhasil dihapus  : ${deleted}`)
  console.log(`✅ Sisa di DB        : ${allDok.length - deleted}`)
  console.log("\n✅ Selesai!")
}

main()
  .catch((err) => {
    console.error("❌", err.message)
    process.exitCode = 1
  })
  .finally(() => db.end())
