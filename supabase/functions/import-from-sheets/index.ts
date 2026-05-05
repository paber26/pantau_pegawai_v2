import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
}

// Tabel yang diizinkan sebagai target impor
const ALLOWED_TABLES = ["users", "kegiatan", "laporan", "dokumentasi"] as const
type AllowedTable = (typeof ALLOWED_TABLES)[number]

interface ImportRowError {
  rowIndex: number
  data: Record<string, unknown>
  message: string
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }

  try {
    // 1. Verifikasi JWT dari Authorization header
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // Gunakan Supabase client biasa (dengan JWT user) untuk verifikasi identitas
    const supabaseClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } }
    })

    const {
      data: { user },
      error: authError
    } = await supabaseClient.auth.getUser()

    if (authError || !user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // 2. Gunakan Supabase Admin client (service role) untuk operasi database — bypass RLS
    const supabaseAdmin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

    // 3. Cek role user dari tabel users
    const { data: userData, error: userError } = await supabaseAdmin
      .from("users")
      .select("role")
      .eq("id", user.id)
      .single()

    if (userError || !userData) {
      return new Response(JSON.stringify({ success: false, error: "Forbidden: user tidak ditemukan" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    if (userData.role !== "admin") {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden: hanya admin yang dapat mengimpor data" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // 4. Parse request body
    let body: { targetTable: string; rows: Record<string, unknown>[] }
    try {
      body = await req.json()
    } catch {
      return new Response(JSON.stringify({ success: false, error: "Request body tidak valid (bukan JSON)" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const { targetTable, rows } = body

    // 5. Validasi targetTable
    if (!targetTable || !ALLOWED_TABLES.includes(targetTable as AllowedTable)) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `targetTable tidak valid. Nilai yang diizinkan: ${ALLOWED_TABLES.join(", ")}`
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Validasi rows
    if (!Array.isArray(rows) || rows.length === 0) {
      return new Response(JSON.stringify({ success: false, error: "rows harus berupa array yang tidak kosong" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // 6. Proses upsert per baris — error per baris tidak menghentikan proses
    const errors: ImportRowError[] = []
    let successCount = 0

    for (const [index, row] of rows.entries()) {
      try {
        const { error: upsertError } = await supabaseAdmin.from(targetTable).upsert(row)

        if (upsertError) {
          errors.push({
            rowIndex: index,
            data: row,
            message: upsertError.message
          })
        } else {
          successCount++
        }
      } catch (err) {
        errors.push({
          rowIndex: index,
          data: row,
          message: (err as Error).message
        })
      }
    }

    // 7. Response sukses dengan statistik impor
    return new Response(
      JSON.stringify({
        success: true,
        imported: successCount,
        failed: errors.length,
        errors
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error) {
    console.error("Unexpected error:", error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
