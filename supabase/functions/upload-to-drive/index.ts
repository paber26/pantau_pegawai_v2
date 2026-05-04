/**
 * Supabase Edge Function: upload-to-drive
 *
 * Menerima file foto dari Flutter app, mengupload ke Google Drive
 * menggunakan Service Account, dan mengembalikan URL file.
 *
 * Environment variables yang dibutuhkan (set via Supabase Dashboard > Edge Functions > Secrets):
 *   GOOGLE_SERVICE_ACCOUNT_EMAIL  - email service account
 *   GOOGLE_PRIVATE_KEY            - private key (dengan \n literal)
 *   GOOGLE_DRIVE_ROOT_FOLDER_ID   - ID folder root di Google Drive
 *   SUPABASE_URL                  - otomatis tersedia
 *   SUPABASE_ANON_KEY             - otomatis tersedia
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ── Google Drive helpers ──────────────────────────────────────────────────────

const GOOGLE_SERVICE_ACCOUNT_EMAIL = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL")!
const GOOGLE_PRIVATE_KEY = Deno.env.get("GOOGLE_PRIVATE_KEY")!.replace(/\\n/g, "\n")
const ROOT_FOLDER_ID = Deno.env.get("GOOGLE_DRIVE_ROOT_FOLDER_ID")!

/**
 * Membuat JWT untuk Google Service Account dan menukarnya dengan access token.
 */
async function getGoogleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  const header = { alg: "RS256", typ: "JWT" }
  const payload = {
    iss: GOOGLE_SERVICE_ACCOUNT_EMAIL,
    scope: "https://www.googleapis.com/auth/drive",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  }

  const encode = (obj: object) => btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")

  const headerB64 = encode(header)
  const payloadB64 = encode(payload)
  const signingInput = `${headerB64}.${payloadB64}`

  // Import private key
  const pemContents = GOOGLE_PRIVATE_KEY.replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")

  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0))
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(signingInput))

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")

  const jwt = `${signingInput}.${signatureB64}`

  // Exchange JWT untuk access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt
    })
  })

  if (!tokenResponse.ok) {
    const err = await tokenResponse.text()
    throw new Error(`Gagal mendapatkan Google access token: ${err}`)
  }

  const tokenData = await tokenResponse.json()
  return tokenData.access_token as string
}

/**
 * Mencari atau membuat folder di Google Drive.
 * Mengembalikan folder ID.
 */
async function getOrCreateFolder(accessToken: string, folderName: string, parentId: string): Promise<string> {
  // Cari folder yang sudah ada
  const searchUrl = new URL("https://www.googleapis.com/drive/v3/files")
  searchUrl.searchParams.set(
    "q",
    `name='${folderName}' and mimeType='application/vnd.google-apps.folder' and '${parentId}' in parents and trashed=false`
  )
  searchUrl.searchParams.set("fields", "files(id,name)")

  const searchRes = await fetch(searchUrl.toString(), {
    headers: { Authorization: `Bearer ${accessToken}` }
  })

  const searchData = await searchRes.json()
  if (searchData.files && searchData.files.length > 0) {
    return searchData.files[0].id as string
  }

  // Buat folder baru
  const createRes = await fetch("https://www.googleapis.com/drive/v3/files", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      name: folderName,
      mimeType: "application/vnd.google-apps.folder",
      parents: [parentId]
    })
  })

  const createData = await createRes.json()
  return createData.id as string
}

/**
 * Upload file ke Google Drive dan set permission public.
 * Mengembalikan URL yang bisa dibuka.
 */
async function uploadFileToDrive(
  accessToken: string,
  fileBytes: Uint8Array,
  filename: string,
  folderId: string
): Promise<string> {
  // Multipart upload
  const boundary = "pantau_pegawai_boundary"
  const metadata = JSON.stringify({
    name: filename,
    parents: [folderId]
  })

  const body = [
    `--${boundary}`,
    "Content-Type: application/json; charset=UTF-8",
    "",
    metadata,
    `--${boundary}`,
    "Content-Type: image/jpeg",
    "",
    ""
  ].join("\r\n")

  const bodyBytes = new TextEncoder().encode(body)
  const endBytes = new TextEncoder().encode(`\r\n--${boundary}--`)

  const combined = new Uint8Array(bodyBytes.length + fileBytes.length + endBytes.length)
  combined.set(bodyBytes, 0)
  combined.set(fileBytes, bodyBytes.length)
  combined.set(endBytes, bodyBytes.length + fileBytes.length)

  const uploadRes = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": `multipart/related; boundary=${boundary}`
    },
    body: combined
  })

  if (!uploadRes.ok) {
    const err = await uploadRes.text()
    throw new Error(`Upload ke Drive gagal: ${err}`)
  }

  const uploadData = await uploadRes.json()
  const fileId = uploadData.id as string

  // Set permission: anyone with link can view
  await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}/permissions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ role: "reader", type: "anyone" })
  })

  // Return URL yang bisa ditampilkan langsung
  return `https://drive.google.com/uc?export=view&id=${fileId}`
}

// ── Main handler ─────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type"
      }
    })
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405
    })
  }

  try {
    // 1. Verifikasi Supabase JWT
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401
      })
    }

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } }
    })

    const {
      data: { user },
      error: authError
    } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401
      })
    }

    // 2. Parse multipart form data
    const formData = await req.formData()
    const file = formData.get("file") as File | null
    const pegawaiNama = formData.get("pegawai_nama") as string | null
    const tanggal = formData.get("tanggal") as string | null
    const filename = formData.get("filename") as string | null

    if (!file || !pegawaiNama || !tanggal || !filename) {
      return new Response(JSON.stringify({ error: "Parameter tidak lengkap: file, pegawai_nama, tanggal, filename" }), {
        status: 400
      })
    }

    const fileBytes = new Uint8Array(await file.arrayBuffer())

    // 3. Dapatkan Google access token
    const accessToken = await getGoogleAccessToken()

    // 4. Buat struktur folder: /PantauPegawai/{nama_pegawai}/{yyyy-mm-dd}/
    const rootFolderId = await getOrCreateFolder(accessToken, "PantauPegawai", ROOT_FOLDER_ID)
    const pegawaiFolderId = await getOrCreateFolder(accessToken, pegawaiNama, rootFolderId)
    const dateFolderId = await getOrCreateFolder(accessToken, tanggal, pegawaiFolderId)

    // 5. Upload file
    const imageUrl = await uploadFileToDrive(accessToken, fileBytes, filename, dateFolderId)

    return new Response(JSON.stringify({ image_url: imageUrl }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    })
  } catch (error) {
    console.error("Error:", error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    })
  }
})
