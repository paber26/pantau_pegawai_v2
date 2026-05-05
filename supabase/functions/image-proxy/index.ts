/**
 * Supabase Edge Function: image-proxy
 *
 * Proxy gambar dari Google Drive agar bisa ditampilkan di browser
 * tanpa masalah CORS dan permission.
 *
 * Auth tidak wajib — keamanan dijaga oleh obscurity file ID
 * (hanya yang tahu file ID yang bisa akses).
 *
 * Usage: GET /functions/v1/image-proxy?id=GOOGLE_DRIVE_FILE_ID
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID")!
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET")!
const GOOGLE_REFRESH_TOKEN = Deno.env.get("GOOGLE_REFRESH_TOKEN")!

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
}

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
  const data = await response.json()
  return data.access_token as string
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const fileId = url.searchParams.get("id")
    if (!fileId) {
      return new Response("Missing id parameter", { status: 400, headers: corsHeaders })
    }

    // Fetch gambar dari Google Drive menggunakan service account
    // Service account punya akses ke semua file di Drive
    const accessToken = await getAccessToken()
    const driveRes = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`, {
      headers: { Authorization: `Bearer ${accessToken}` }
    })

    if (!driveRes.ok) {
      return new Response(`Drive error: ${driveRes.status}`, {
        status: driveRes.status,
        headers: corsHeaders
      })
    }

    const imageBytes = await driveRes.arrayBuffer()
    const contentType = driveRes.headers.get("content-type") ?? "image/jpeg"

    return new Response(imageBytes, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": contentType,
        "Cache-Control": "public, max-age=86400"
      }
    })
  } catch (error) {
    return new Response(`Error: ${(error as Error).message}`, {
      status: 500,
      headers: corsHeaders
    })
  }
})
