#!/usr/bin/env bash
#
# sync.sh — wrapper untuk menjalankan sinkronisasi data dari Google
# Spreadsheet (AppSheet lama) ke Supabase.
#
# Membaca SUPABASE_SERVICE_ROLE_KEY dari .envbackup lalu memanggil
# scripts/migrate-from-sheets.js. Aman dijalankan berkali-kali karena
# script migrasi melakukan deduplikasi otomatis berdasarkan
# (user_id, tanggal_kegiatan, proyek).
#
# Pemakaian:
#   ./sync.sh
#
# Kebutuhan:
#   - File .envbackup berisi baris "Supabase Service Role Key = <jwt>"
#   - Node.js terinstal dan node_modules sudah ada
#     (jalankan `npm install @supabase/supabase-js` bila belum).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.envbackup"
MIGRATE_SCRIPT="$SCRIPT_DIR/scripts/migrate-from-sheets.js"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE tidak ditemukan."
  echo "Pastikan file .envbackup berisi baris:"
  echo "  Supabase Service Role Key = <jwt>"
  exit 1
fi

if [[ ! -f "$MIGRATE_SCRIPT" ]]; then
  echo "ERROR: $MIGRATE_SCRIPT tidak ditemukan."
  exit 1
fi

# Ekstrak service role key dari .envbackup. Format yang didukung:
#   Supabase Service Role Key = eyJ...
SUPABASE_SERVICE_ROLE_KEY="$(grep -E '^[[:space:]]*Supabase Service Role Key[[:space:]]*=' "$ENV_FILE" \
  | head -n 1 \
  | sed -E 's/^[^=]+=[[:space:]]*//' \
  | tr -d '[:space:]')"

if [[ -z "$SUPABASE_SERVICE_ROLE_KEY" ]]; then
  echo "ERROR: Tidak menemukan 'Supabase Service Role Key = ...' di $ENV_FILE"
  exit 1
fi

echo "==> Menjalankan sinkronisasi data dari Google Spreadsheet..."
echo ""

SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" node "$MIGRATE_SCRIPT"
