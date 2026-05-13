import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Service Account credentials (set via Supabase secrets)
const SERVICE_ACCOUNT_EMAIL = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL")!
const PRIVATE_KEY = Deno.env.get("GOOGLE_PRIVATE_KEY")!
const ROOT_FOLDER_ID = Deno.env.get("GOOGLE_DRIVE_ROOT_FOLDER_ID")!

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
}

// Buat JWT untuk Service Account Google
async function createServiceAccountJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "RS256", typ: "JWT" }
  const payload = {
    iss: SERVICE_ACCOUNT_EMAIL,
    scope: "https://www.googleapis.com/auth/drive",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  }

  const encode = (obj: object) => btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")

  const headerB64 = encode(header)
  const payloadB64 = encode(payload)
  const signingInput = `${headerB64}.${payloadB64}`

  const pemKey = PRIVATE_KEY.replace(/\\n/g, "\n")
  const keyData = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0))
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

  return `${signingInput}.${signatureB64}`
}

// Dapatkan access token via Service Account JWT
async function getAccessToken(): Promise<string> {
  const jwt = await createServiceAccountJWT()

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt
    })
  })

  const data = await response.json()
  if (!data.access_token) {
    throw new Error(`Gagal refresh access token: ${JSON.stringify(data)}`)
  }
  return data.access_token as string
}

// Cari atau buat folder di Google Drive
async function getOrCreateFolder(accessToken: string, folderName: string, parentId: string): Promise<string> {
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

  if (!createRes.ok) {
    const err = await createRes.text()
    throw new Error(`Gagal buat folder '${folderName}': ${err}`)
  }

  const createData = await createRes.json()
  return createData.id as string
}

// Upload file ke Google Drive
async function uploadFile(
  accessToken: string,
  fileBytes: Uint8Array,
  filename: string,
  folderId: string
): Promise<string> {
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

  // Return URL proxy Supabase
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  return `${supabaseUrl}/functions/v1/image-proxy?id=${fileId}`
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: corsHeaders
    })
  }

  try {
    // Verifikasi Supabase JWT
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders
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
        status: 401,
        headers: corsHeaders
      })
    }

    // Parse form data
    const formData = await req.formData()
    const file = formData.get("file") as File | null
    const pegawaiNama = formData.get("pegawai_nama") as string | null
    const tanggal = formData.get("tanggal") as string | null
    const filename = formData.get("filename") as string | null

    if (!file || !pegawaiNama || !tanggal || !filename) {
      return new Response(JSON.stringify({ error: "Parameter tidak lengkap" }), { status: 400, headers: corsHeaders })
    }

    const fileBytes = new Uint8Array(await file.arrayBuffer())

    // Dapatkan access token via Service Account
    const accessToken = await getAccessToken()

    // Buat struktur folder: ROOT/{nama_pegawai}/{yyyy-mm-dd}/
    const pegawaiFolderId = await getOrCreateFolder(accessToken, pegawaiNama, ROOT_FOLDER_ID)
    const dateFolderId = await getOrCreateFolder(accessToken, tanggal, pegawaiFolderId)

    // Upload file
    const imageUrl = await uploadFile(accessToken, fileBytes, filename, dateFolderId)

    return new Response(JSON.stringify({ image_url: imageUrl }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  } catch (error) {
    console.error("Error:", error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
