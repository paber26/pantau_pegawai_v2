#!/usr/bin/env node
/**
 * Script migrasi data sekali jalan dari Google Spreadsheet ke Supabase.
 * Cara jalankan:
 *   SUPABASE_SERVICE_ROLE_KEY=xxx node scripts/migrate-from-sheets.js
 */

const { createClient } = require("@supabase/supabase-js")

const SPREADSHEET_ID = "1IvEhH5DvIDKKg7U61StDUAr6hYlyeYQYjzibnC4Bxj4"
const GOOGLE_SHEETS_API_KEY = "AIzaSyAj7-Sm2ScvRNprljcC-8CzOTshwh-J0k8"
const SUPABASE_URL = "https://glywzqbifjordhwulpbw.supabase.co"
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ""
const DEFAULT_PASSWORD = "@@Password"

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("❌ Set SUPABASE_SERVICE_ROLE_KEY terlebih dahulu")
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
})

// Mapping nama lengkap di spreadsheet → email di Supabase
const NAMA_MAPPING = {
  "Irena Listianawati SST, SE., M.Si": "irena@bps.go.id",
  "Sri Endang T Karim SE": "srikarim@bps.go.id",
  "Johanes S.ST": "johanes@bps.go.id",
  "Jimmy Ferdinan Mamahani SE": "jimmy@bps.go.id",
  "Frenly Wongkar S.Si": "frenlyw@bps.go.id",
  "Ireyne Tamburian S.Sos": "ireyne@bps.go.id",
  "Widhita Krisnahapsari S.ST., M.SE.": "dhitakrisna@bps.go.id",
  "Diane Roosjefien Rondonuwu S.P.": "diane.rondonuwu@bps.go.id",
  "Meity Chintya Sinadia SE": "meity.sinadia@bps.go.id",
  "Dodik Setyawan S.Tr.Stat.": "dodik.setayawan@bps.go.id",
  "Afwin Fauzy Akhsan S.Tr.Stat.": "afwinfzy@bps.go.id",
  "Yunanda Angelia Sinurat S.Tr.Stat.": "yeaes@bps.go.id",
  "Artha Gumelar Suharsa S.Tr.Stat.": "artha.suharsa@bps.go.id",
  "Syahfianti Inung Pratiwi S.Tr.Stat.": "inung.pratiwi@bps.go.id",
  "Melati Sukmaningtyas S.Tr.Stat.": "melati.sukma@bps.go.id",
  "Pidyatama Putri Situmorang S.Tr.Stat.": "putri.situmorang@bps.go.id",
  "Vincentius Agra Ananta Gunito S.Tr.Stat.": "vincagra@bps.go.id",
  "Steven Bonny Reppi S.E.": "steven.repi@bps.go.id",
  "Kurniawan Winston Walangitan SE": "wanlyraffa@bps.go.id",
  "Alfie Gustaf Paul Sunkudon S.Pd": "alfie.sunkudon@bps.go.id",
  "Joice Rorimpandey A.Md": "jho_luvjc@bps.go.id",
  "Jelly Jevry Tapada A.Md": "jellyjevry-pppk@bps.go.id",
  "Hendra Peddro Riekho Sunkudon": "hendrapeddro-pppk@bps.go.id",
  "Sem Ham Lumempow": "semlumempow@gmail.com",
  "Bernaldo Napitupulu S.Tr.Stat.": "bernaldon@bps.go.id",
  "Daniel Albert Manaf": null, // tidak ada di daftar pegawai, skip
  "Frensix Katihokang": null // tidak ada di daftar pegawai, skip
}

async function fetchSheetData(sheetName) {
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/${encodeURIComponent(sheetName)}?key=${GOOGLE_SHEETS_API_KEY}`
  const res = await fetch(url)
  if (!res.ok) throw new Error(`Gagal fetch "${sheetName}": ${res.status}`)
  return (await res.json()).values || []
}

function rowsToObjects(rows) {
  if (rows.length < 2) return []
  const headers = rows[0]
  return rows.slice(1).map((row) => {
    const obj = {}
    headers.forEach((h, i) => {
      obj[h] = row[i] || ""
    })
    return obj
  })
}

function parseDate(s) {
  if (!s) return null
  if (s.includes("-") && !isNaN(new Date(s).getTime())) return new Date(s).toISOString().split("T")[0]
  const p = s.split("/")
  if (p.length === 3) return `${p[2]}-${p[0].padStart(2, "0")}-${p[1].padStart(2, "0")}`
  return null
}

async function main() {
  console.log("🚀 Migrasi data dari Google Spreadsheet ke Supabase...\n")

  // Ambil semua user yang sudah ada
  const { data: allUsers } = await supabase.from("users").select("id, nama, email")
  const userMap = allUsers || []
  console.log(`👥 ${userMap.length} pegawai sudah ada di Supabase`)
  userMap.forEach((u) => console.log(`   - ${u.nama} | ${u.email}`))

  // Baca DOKUMENTASI HARIAN
  console.log("\n📋 Membaca DOKUMENTASI HARIAN...")
  const rows = await fetchSheetData("DOKUMENTASI HARIAN")
  const records = rowsToObjects(rows)
  console.log(`   ${records.length} baris ditemukan`)

  // Ambil dokumentasi yang sudah ada untuk skip duplikat
  const { data: existingDok } = await supabase.from("dokumentasi").select("user_id, tanggal_kegiatan, proyek")
  const existingKeys = new Set((existingDok || []).map((d) => `${d.user_id}|${d.tanggal_kegiatan}|${d.proyek}`))
  console.log(`   ${existingKeys.size} dokumentasi sudah ada di Supabase (akan di-skip)`)

  // Proses semua baris
  const toInsert = []
  let dilewati = 0
  let errorParse = 0
  const parseErrors = []

  for (const [i, record] of records.entries()) {
    const namaPegawai = record["PEGAWAI"]?.trim()
    const proyek = record["PROYEK"]?.trim()
    const tanggalStr = record["TANGGAL KEGIATAN"]?.trim()
    const catatan = record["CATATAN"]?.trim() || null
    const link = record["LINK"]?.trim() || null

    if (!namaPegawai && !proyek) {
      dilewati++
      continue
    }

    // Cari user via mapping
    const mappedEmail = NAMA_MAPPING[namaPegawai]
    if (mappedEmail === null) {
      dilewati++
      continue
    } // sengaja skip

    let user = null
    if (mappedEmail) {
      user = userMap.find((u) => u.email?.toLowerCase() === mappedEmail.toLowerCase())
    }
    // Fallback fuzzy match
    if (!user && namaPegawai) {
      user = userMap.find(
        (u) =>
          u.nama?.toLowerCase().includes(namaPegawai.toLowerCase()) ||
          namaPegawai.toLowerCase().includes(u.nama?.toLowerCase())
      )
    }

    if (!user) {
      parseErrors.push(`Baris ${i + 2}: "${namaPegawai}" tidak ditemukan`)
      errorParse++
      continue
    }

    const tanggal = parseDate(tanggalStr)
    if (!tanggal) {
      parseErrors.push(`Baris ${i + 2}: tanggal tidak valid "${tanggalStr}"`)
      errorParse++
      continue
    }

    if (!proyek) {
      errorParse++
      continue
    }

    // Skip duplikat
    const key = `${user.id}|${tanggal}|${proyek}`
    if (existingKeys.has(key)) {
      dilewati++
      continue
    }
    existingKeys.add(key)

    toInsert.push({ user_id: user.id, proyek, tanggal_kegiatan: tanggal, catatan, link, image_url: link })
  }

  console.log(`\n   Siap insert: ${toInsert.length} baris baru`)
  console.log(`   Dilewati   : ${dilewati} (kosong/duplikat/tidak ada di daftar)`)
  console.log(`   Error parse: ${errorParse}`)

  if (toInsert.length === 0) {
    console.log("\n✅ Tidak ada data baru untuk diinsert.")
    return
  }

  // Batch insert 200 baris sekaligus
  const BATCH = 200
  let berhasil = 0
  let gagalInsert = 0
  const insertErrors = []

  for (let i = 0; i < toInsert.length; i += BATCH) {
    const chunk = toInsert.slice(i, i + BATCH)
    const batchNum = Math.floor(i / BATCH) + 1
    const totalBatch = Math.ceil(toInsert.length / BATCH)
    process.stdout.write(`   Batch ${batchNum}/${totalBatch}... `)

    const { error } = await supabase.from("dokumentasi").insert(chunk)
    if (error) {
      console.log(`❌ ${error.message}`)
      insertErrors.push(`Batch ${batchNum}: ${error.message}`)
      gagalInsert += chunk.length
    } else {
      berhasil += chunk.length
      console.log(`✅ ${berhasil}/${toInsert.length}`)
    }
  }

  // Laporan akhir
  console.log("\n" + "=".repeat(50))
  console.log("📊 LAPORAN MIGRASI")
  console.log("=".repeat(50))
  console.log(`✅ Berhasil diinsert : ${berhasil}`)
  console.log(`⏭️  Dilewati          : ${dilewati}`)
  console.log(`❌ Error parse       : ${errorParse}`)
  console.log(`❌ Error insert      : ${gagalInsert}`)

  if (parseErrors.length > 0) {
    console.log("\nError parse (max 10):")
    parseErrors.slice(0, 10).forEach((e) => console.log(`  - ${e}`))
  }
  if (insertErrors.length > 0) {
    console.log("\nError insert:")
    insertErrors.forEach((e) => console.log(`  - ${e}`))
  }

  console.log("\n✅ Selesai!")
}

main().catch((err) => {
  console.error("❌", err.message)
  process.exit(1)
})
