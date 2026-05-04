/**
 * Supabase Edge Function: admin-reset-password
 *
 * Mengizinkan admin untuk mengubah password user lain.
 * Hanya bisa dipanggil oleh user dengan role 'admin'.
 *
 * Environment variables (otomatis tersedia di Edge Functions):
 *   SUPABASE_URL
 *   SUPABASE_ANON_KEY
 *   SUPABASE_SERVICE_ROLE_KEY  ← set manual via secrets
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
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
    // 1. Verifikasi caller adalah admin
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders
      })
    }

    // Client dengan JWT caller untuk verifikasi role
    const callerClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } }
    })

    const {
      data: { user: caller },
      error: authError
    } = await callerClient.auth.getUser()

    if (authError || !caller) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders
      })
    }

    // Cek role admin dari tabel users
    const { data: callerProfile } = await callerClient.from("users").select("role").eq("id", caller.id).single()

    if (callerProfile?.role !== "admin") {
      return new Response(JSON.stringify({ error: "Forbidden: hanya admin yang bisa mengubah password" }), {
        status: 403,
        headers: corsHeaders
      })
    }

    // 2. Parse body
    const { user_id, new_password } = await req.json()

    if (!user_id || !new_password) {
      return new Response(JSON.stringify({ error: "user_id dan new_password wajib diisi" }), {
        status: 400,
        headers: corsHeaders
      })
    }

    if (new_password.length < 6) {
      return new Response(JSON.stringify({ error: "Password minimal 6 karakter" }), {
        status: 400,
        headers: corsHeaders
      })
    }

    // 3. Update password menggunakan service role key
    const adminClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SERVICE_ROLE_KEY")!)

    const { error: updateError } = await adminClient.auth.admin.updateUserById(user_id, { password: new_password })

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500, headers: corsHeaders })
    }

    return new Response(JSON.stringify({ success: true, message: "Password berhasil diubah" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  } catch (error) {
    console.error("Error:", error)
    return new Response(JSON.stringify({ error: (error as Error).message }), { status: 500, headers: corsHeaders })
  }
})
