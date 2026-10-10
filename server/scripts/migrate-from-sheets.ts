/**
 * Sinkronisasi data dari Google Spreadsheet (AppSheet lama) ke database.
 * Aman dijalankan berkali-kali: baris yang sudah ada dilewati berdasarkan
 * (user_id, tanggal_kegiatan, proyek).
 *
 * Cara jalankan (dari folder server/, atau lewat ./sync.sh di root repo):
 *   DATABASE_URL=postgres://... GOOGLE_SHEETS_API_KEY=xxx npx tsx scripts/migrate-from-sheets.ts
 */
import pg from "pg"

pg.types.setTypeParser(pg.types.builtins.DATE, (v) => v)

const SPREADSHEET_ID = process.env.SPREADSHEET_ID ?? "1IvEhH5DvIDKKg7U61StDUAr6hYlyeYQYjzibnC4Bxj4"
const GOOGLE_SHEETS_API_KEY = process.env.GOOGLE_SHEETS_API_KEY ?? ""
const DATABASE_URL = process.env.DATABASE_URL ?? ""

if (!DATABASE_URL || !GOOGLE_SHEETS_API_KEY) {
  console.error("❌ Set DATABASE_URL dan GOOGLE_SHEETS_API_KEY terlebih dahulu")
  process.exit(1)
}

const db = new pg.Pool({ connectionString: DATABASE_URL })

interface UserRow {
  id: string
  nama: string
  email: string
}

// Mapping nama lengkap di spreadsheet → email akun pegawai
const NAMA_MAPPING: Record<string, string | null> = {
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

async function fetchSheetData(sheetName: string): Promise<string[][]> {
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/${encodeURIComponent(sheetName)}?key=${GOOGLE_SHEETS_API_KEY}`
  const res = await fetch(url)
  if (!res.ok) throw new Error(`Gagal fetch "${sheetName}": ${res.status}`)
  return (await res.json()).values || []
}

function rowsToObjects(rows: string[][]): Record<string, string>[] {
  if (rows.length < 2) return []
  const headers = rows[0]
  return rows.slice(1).map((row) => {
    const obj: Record<string, string> = {}
    headers.forEach((h, i) => {
      obj[h] = row[i] || ""
    })
    return obj
  })
}

function parseDate(s: string | undefined): string | null {
  if (!s) return null
  if (s.includes("-") && !isNaN(new Date(s).getTime())) return new Date(s).toISOString().split("T")[0]
  const p = s.split("/")
  if (p.length === 3) return `${p[2]}-${p[0].padStart(2, "0")}-${p[1].padStart(2, "0")}`
  return null
}

async function main() {
  console.log("🚀 Sinkronisasi data dari Google Spreadsheet ke database...\n")

  // Ambil semua user yang sudah ada
  const { rows: userMap } = await db.query<UserRow>("SELECT id, nama, email FROM users")
  console.log(`👥 ${userMap.length} pegawai sudah ada di database`)
  userMap.forEach((u) => console.log(`   - ${u.nama} | ${u.email}`))

  // Baca DOKUMENTASI HARIAN
  console.log("\n📋 Membaca DOKUMENTASI HARIAN...")
  const rows = await fetchSheetData("DOKUMENTASI HARIAN")
  const records = rowsToObjects(rows)
  console.log(`   ${records.length} baris ditemukan`)

  // Ambil dokumentasi yang sudah ada untuk skip duplikat
  const { rows: existingDok } = await db.query<{ user_id: string; tanggal_kegiatan: string; proyek: string }>(
    "SELECT user_id, tanggal_kegiatan, proyek FROM dokumentasi"
  )
  const existingKeys = new Set(existingDok.map((d) => `${d.user_id}|${d.tanggal_kegiatan}|${d.proyek}`))
  console.log(`   ${existingDok.length} dokumentasi sudah ada di database (akan di-skip)`)

  // Proses semua baris
  const toInsert: {
    user_id: string
    pegawai_nama: string
    proyek: string
    tanggal_kegiatan: string
    catatan: string | null
    link: string | null
    image_url: string | null
  }[] = []
  let dilewati = 0
  let errorParse = 0
  const parseErrors: string[] = []

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

    let user: UserRow | undefined
    if (mappedEmail) {
      user = userMap.find((u) => u.email?.toLowerCase() === mappedEmail.toLowerCase())
    }
    // Fallback fuzzy match
    if (!user && namaPegawai) {
      user = userMap.find(
        (u) =>
          u.nama?.toLowerCase().includes(namaPegawai.toLowerCase()) ||
          namaPegawai.toLowerCase().includes(u.nama?.toLowerCase() ?? "")
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

    toInsert.push({ user_id: user.id, pegawai_nama: user.nama, proyek, tanggal_kegiatan: tanggal, catatan, link, image_url: link })
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
  const insertErrors: string[] = []

  for (let i = 0; i < toInsert.length; i += BATCH) {
    const chunk = toInsert.slice(i, i + BATCH)
    const batchNum = Math.floor(i / BATCH) + 1
    const totalBatch = Math.ceil(toInsert.length / BATCH)
    process.stdout.write(`   Batch ${batchNum}/${totalBatch}... `)

    try {
      await db.query(
        `INSERT INTO dokumentasi (user_id, pegawai_nama, proyek, tanggal_kegiatan, catatan, link, image_url)
         SELECT user_id, pegawai_nama, proyek, tanggal_kegiatan, catatan, link, image_url
           FROM json_populate_recordset(NULL::dokumentasi, $1::json)`,
        [JSON.stringify(chunk)]
      )
      berhasil += chunk.length
      console.log(`✅ ${berhasil}/${toInsert.length}`)
    } catch (error) {
      const message = (error as Error).message
      console.log(`❌ ${message}`)
      insertErrors.push(`Batch ${batchNum}: ${message}`)
      gagalInsert += chunk.length
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

main()
  .catch((err) => {
    console.error("❌", err.message)
    process.exitCode = 1
  })
  .finally(() => db.end())
