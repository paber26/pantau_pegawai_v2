/**
 * Supabase Edge Function: image-proxy
 *
 * Proxy gambar dari Google Drive agar bisa ditampilkan di browser
 * tanpa masalah CORS. Browser request ke Supabase, Supabase fetch
 * dari Google Drive dan return bytes-nya.
 *
 * Usage: GET /functions/v1/image-proxy?id=GOOGLE_DRIVE_FILE_ID
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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
    // Verifikasi Supabase JWT
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders })
    }

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } }
    })

    const {
      data: { user },
      error
    } = await supabase.auth.getUser()
    if (error || !user) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders })
    }

    // Ambil file ID dari query param
    const url = new URL(req.url)
    const fileId = url.searchParams.get("id")
    if (!fileId) {
      return new Response("Missing id parameter", { status: 400, headers: corsHeaders })
    }

    // Fetch gambar dari Google Drive
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
        "Cache-Control": "public, max-age=86400" // cache 1 hari
      }
    })
  } catch (error) {
    return new Response(`Error: ${(error as Error).message}`, {
      status: 500,
      headers: corsHeaders
    })
  }
})
