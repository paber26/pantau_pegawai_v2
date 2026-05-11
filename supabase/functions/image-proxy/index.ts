/**
 * Supabase Edge Function: image-proxy
 *
 * Proxy gambar dari Google Drive menggunakan Service Account.
 * Service Account tidak pernah expired — lebih reliable dari OAuth refresh token.
 *
 * Usage: GET /functions/v1/image-proxy?id=GOOGLE_DRIVE_FILE_ID
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const SERVICE_ACCOUNT_EMAIL = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL")!
const PRIVATE_KEY = Deno.env.get("GOOGLE_PRIVATE_KEY")!

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
}

// Buat JWT untuk Service Account Google
async function createServiceAccountJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "RS256", typ: "JWT" }
  const payload = {
    iss: SERVICE_ACCOUNT_EMAIL,
    scope: "https://www.googleapis.com/auth/drive.readonly",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  }

  const encode = (obj: object) => btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")

  const headerB64 = encode(header)
  const payloadB64 = encode(payload)
  const signingInput = `${headerB64}.${payloadB64}`

  // Import private key
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
    throw new Error(`Failed to get access token: ${JSON.stringify(data)}`)
  }
  return data.access_token as string
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const fileId = url.searchParams.get("id")
    // Support apikey as query param untuk akses langsung dari browser
    // tanpa perlu Authorization header
    if (!fileId) {
      return new Response("Missing id parameter", { status: 400, headers: corsHeaders })
    }

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
