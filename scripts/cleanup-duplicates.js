#!/usr/bin/env node
/**
 * Cleanup duplikat di tabel `dokumentasi`.
 *
 * Duplikat didefinisikan sebagai baris dengan kombinasi yang sama untuk
 * (user_id, tanggal_kegiatan, proyek). Untuk setiap kelompok duplikat,
 * baris dengan `created_at` paling lama dipertahankan; sisanya dihapus.
 *
 * Cara jalankan:
 *   SUPABASE_SERVICE_ROLE_KEY=xxx node scripts/cleanup-duplicates.js
 *
 * Tambah --dry-run untuk hanya menampilkan apa yang akan dihapus tanpa
 * benar-benar menghapus.
 */

const { createClient } = require("@supabase/supabase-js")

const SUPABASE_URL = "https://glywzqbifjordhwulpbw.supabase.co"
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ""
const DRY_RUN = process.argv.includes("--dry-run")

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("❌ Set SUPABASE_SERVICE_ROLE_KEY terlebih dahulu")
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
})

async function fetchAllDokumentasi() {
  const PAGE_SIZE = 1000
  const all = []
  let page = 0
  while (true) {
    const from = page * PAGE_SIZE
    const to = from + PAGE_SIZE - 1
    const { data, error } = await supabase
      .from("dokumentasi")
      .select("id, user_id, tanggal_kegiatan, proyek, created_at")
      .order("created_at", { ascending: true })
      .range(from, to)
    if (error) throw new Error(`Gagal baca page ${page}: ${error.message}`)
    if (!data || data.length === 0) break
    all.push(...data)
    if (data.length < PAGE_SIZE) break
    page++
  }
  return all
}

async function main() {
  console.log("🧹 Cleanup duplikat dokumentasi...\n")
  if (DRY_RUN) console.log("⚠️  DRY RUN — tidak akan menghapus apapun\n")

  const allDok = await fetchAllDokumentasi()
  console.log(`📋 Total baris di DB: ${allDok.length}`)

  // Group by (user_id, tanggal_kegiatan, proyek)
  const groups = new Map()
  for (const dok of allDok) {
    const key = `${dok.user_id}|${dok.tanggal_kegiatan}|${dok.proyek}`
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key).push(dok)
  }

  // Cari kelompok yang punya duplikat (>1 baris)
  const duplicateGroups = []
  const idsToDelete = []
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

    const { error } = await supabase.from("dokumentasi").delete().in("id", chunk)
    if (error) {
      console.log(`❌ ${error.message}`)
      throw new Error(`Batch ${batchNum} gagal: ${error.message}`)
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

main().catch((err) => {
  console.error("❌", err.message)
  process.exit(1)
})
