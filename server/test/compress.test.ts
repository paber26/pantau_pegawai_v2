import { brotliDecompressSync, gunzipSync } from "node:zlib"

import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { bearer, seedUsers, setup, teardown, type TestEnv } from "./helpers.js"

let env: TestEnv
let s: Awaited<ReturnType<typeof seedUsers>>

beforeAll(async () => {
  env = await setup()
  s = await seedUsers(env)
  // Mirip data produksi: ±1.600 dokumentasi dengan catatan.
  await env.db.query(
    `INSERT INTO dokumentasi (user_id, proyek, tanggal_kegiatan, catatan, image_url)
     SELECT $1, 'Sensus Ekonomi 2026', DATE '2026-01-01' + (i % 280),
            'Membuat monitoring SE kondisi usaha dan keluarga yang ditemukan ' || i,
            'https://api.contoh.go.id/api/images?id=1AbCdEfGhIjKlMnOpQrStUvWxYz' || i
       FROM generate_series(1, 1600) AS i`,
    [s.budiId]
  )
})
afterAll(() => teardown(env))

describe("kompresi respons", () => {
  it("daftar dokumentasi dikirim terkompresi (br/gzip) dan isinya utuh", async () => {
    const plain = await env.app.inject({ url: "/api/dokumentasi", headers: bearer(s.admin) })
    expect(plain.headers["content-encoding"]).toBeUndefined()
    const asli = plain.rawPayload.length

    const br = await env.app.inject({
      url: "/api/dokumentasi",
      headers: { ...bearer(s.admin), "accept-encoding": "gzip, deflate, br" }
    })
    expect(br.headers["content-encoding"]).toBe("br")
    expect(br.headers.vary).toContain("accept-encoding")
    const isi = JSON.parse(brotliDecompressSync(br.rawPayload).toString())
    expect(isi).toHaveLength(1600)

    const gz = await env.app.inject({
      url: "/api/dokumentasi",
      headers: { ...bearer(s.admin), "accept-encoding": "gzip" }
    })
    expect(gz.headers["content-encoding"]).toBe("gzip")
    expect(JSON.parse(gunzipSync(gz.rawPayload).toString())).toHaveLength(1600)

    // Saat diukur: ±823 KB → ±48 KB (br) / ±51 KB (gzip).
    expect(br.rawPayload.length).toBeLessThan(asli / 4)
    expect(gz.rawPayload.length).toBeLessThan(asli / 4)
  })

  it("respons kecil dan gambar tidak dikompres", async () => {
    const health = await env.app.inject({ url: "/health", headers: { "accept-encoding": "gzip, br" } })
    expect(health.headers["content-encoding"]).toBeUndefined()
    expect(health.json()).toEqual({ status: "ok" })

    const id = await env.drive.uploadFile({
      bytes: Buffer.alloc(4096, 1),
      filename: "foto.jpg",
      mimeType: "image/jpeg",
      folderPath: ["Budi Santoso", "2026-10-24"]
    })
    const img = await env.app.inject({ url: `/api/images?id=${id}`, headers: { "accept-encoding": "gzip, br" } })
    expect(img.statusCode).toBe(200)
    expect(img.headers["content-encoding"]).toBeUndefined()
    expect(img.rawPayload.length).toBe(4096)
  })
})
