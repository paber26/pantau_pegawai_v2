import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// OAuth2 credentials (set via Supabase secrets)
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID")!
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET")!
const GOOGLE_REFRESH_TOKEN = Deno.env.get("GOOGLE_REFRESH_TOKEN")!
const ROOT_FOLDER_ID = Deno.env.get("GOOGLE_DRIVE_ROOT_FOLDER_ID")!

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
}

// Dapatkan access token baru dari refresh token
async function getAccessToken(): Promise<string> {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: GOOGLE_REFRESH_TOKEN,
      grant_type: "refresh_token"
    })
  })

  if (!response.ok) {
    const err = await response.text()
    throw new Error(`Gagal refresh access token: ${err}`)
  }

  const data = await response.json()
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

  // Return URL proxy Supabase (bukan URL Drive langsung) agar bisa ditampilkan di browser
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

    // Dapatkan access token via refresh token
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
