import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? ""
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? ""

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    if (!SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: "SERVICE_ROLE_KEY secret tidak ditemukan" }), {
        status: 500,
        headers: corsHeaders
      })
    }

    // 1. Verifikasi caller adalah admin
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders
      })
    }

    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } }
    })

    const {
      data: { user: caller },
      error: authError
    } = await callerClient.auth.getUser()
    if (authError || !caller) {
      return new Response(JSON.stringify({ error: `Unauthorized: ${authError?.message}` }), {
        status: 401,
        headers: corsHeaders
      })
    }

    const { data: callerProfile } = await callerClient.from("users").select("role").eq("id", caller.id).single()

    if (callerProfile?.role !== "admin") {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: corsHeaders
      })
    }

    // 2. Parse body
    const { nama, email, password, jabatan, unit_kerja, role } = await req.json()

    if (!nama || !email || !password) {
      return new Response(JSON.stringify({ error: "nama, email, password wajib diisi" }), {
        status: 400,
        headers: corsHeaders
      })
    }

    if (password.length < 6) {
      return new Response(JSON.stringify({ error: "Password minimal 6 karakter" }), {
        status: 400,
        headers: corsHeaders
      })
    }

    // 3. Buat user auth
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    })

    if (createError || !newUser.user) {
      return new Response(JSON.stringify({ error: `Gagal buat auth user: ${createError?.message}` }), {
        status: 500,
        headers: corsHeaders
      })
    }

    // 4. Trigger handle_new_user sudah otomatis insert row ke tabel users.
    //    Kita tunggu sebentar lalu update dengan data lengkap.
    await new Promise((resolve) => setTimeout(resolve, 500))

    const { data: profile, error: updateError } = await adminClient
      .from("users")
      .update({
        nama,
        jabatan: jabatan || null,
        unit_kerja: unit_kerja || null,
        role: role || "pegawai"
      })
      .eq("id", newUser.user.id)
      .select()
      .single()

    if (updateError) {
      // Rollback auth user
      await adminClient.auth.admin.deleteUser(newUser.user.id)
      return new Response(JSON.stringify({ error: `Gagal update profil: ${updateError.message}` }), {
        status: 500,
        headers: corsHeaders
      })
    }

    return new Response(JSON.stringify({ success: true, user: profile }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: `Exception: ${error.message}` }), {
      status: 500,
      headers: corsHeaders
    })
  }
})
