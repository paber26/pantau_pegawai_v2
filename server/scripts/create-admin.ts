/**
 * Buat akun admin baru, atau jadikan akun yang sudah ada sebagai admin dan
 * ganti password-nya (berguna bila password admin lupa).
 *
 * Di VPS:
 *   docker compose exec api node dist/scripts/create-admin.js
 *
 * Non-interaktif:
 *   ADMIN_EMAIL=... ADMIN_NAMA=... ADMIN_PASSWORD=... node dist/scripts/create-admin.js
 */
import { stdin, stdout } from "node:process"
import { createInterface } from "node:readline/promises"

import pg from "pg"

import { deleteSessionsOfUser, hashPassword, MIN_PASSWORD_LENGTH } from "../src/auth.js"

async function ask(question: string, hidden = false): Promise<string> {
  const rl = createInterface({ input: stdin, output: stdout, terminal: true })
  if (hidden) {
    // Jangan tampilkan password yang diketik.
    const r = rl as unknown as { _writeToOutput: (s: string) => void }
    r._writeToOutput = (s: string) => {
      if (s.includes(question)) stdout.write(s)
    }
  }
  const answer = await rl.question(question)
  rl.close()
  if (hidden) stdout.write("\n")
  return answer.trim()
}

async function main() {
  const url = process.env.DATABASE_URL
  if (!url) throw new Error("DATABASE_URL belum diset")

  const email = process.env.ADMIN_EMAIL ?? (await ask("Email admin: "))
  const nama = process.env.ADMIN_NAMA ?? (await ask("Nama (kosongkan bila akun sudah ada): "))
  const password = process.env.ADMIN_PASSWORD ?? (await ask("Password baru: ", true))
  if (!email.includes("@")) throw new Error("Email tidak valid")
  if (password.length < MIN_PASSWORD_LENGTH) throw new Error(`Password minimal ${MIN_PASSWORD_LENGTH} karakter`)

  const db = new pg.Client({ connectionString: url })
  await db.connect()
  try {
    const hash = await hashPassword(password)
    const { rows } = await db.query(
      `UPDATE users SET role = 'admin', password_hash = $2, nama = COALESCE(NULLIF($3, ''), nama)
        WHERE lower(email) = lower($1) RETURNING id, nama`,
      [email, hash, nama]
    )
    if (rows[0]) {
      await deleteSessionsOfUser(db, rows[0].id)
      console.log(`✅ ${rows[0].nama} <${email}> sekarang admin dengan password baru.`)
      return
    }
    if (!nama) throw new Error("Akun belum ada; isi nama untuk membuat admin baru")
    await db.query(`INSERT INTO users (nama, email, role, password_hash) VALUES ($1, $2, 'admin', $3)`, [
      nama,
      email,
      hash
    ])
    console.log(`✅ Admin baru dibuat: ${nama} <${email}>`)
  } finally {
    await db.end()
  }
}

main().catch((err) => {
  console.error(`❌ ${err.message}`)
  process.exitCode = 1
})
