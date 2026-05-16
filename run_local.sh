#!/usr/bin/env bash
#
# run_local.sh — menjalankan aplikasi Flutter secara lokal dengan
# environment variables dari file `.env`.
#
# Pemakaian:
#   ./run_local.sh                       # default device (Chrome)
#   ./run_local.sh chrome                # web di Chrome
#   ./run_local.sh macos                 # desktop macOS
#   ./run_local.sh <device-id>           # device spesifik (mis. iPhone)
#
# Tips:
#   - Untuk melihat daftar device: `flutter devices`
#   - Edit file `.env` untuk mengganti URL/key Supabase atau Sheets API.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE tidak ditemukan."
  echo "Buat file .env terlebih dahulu (lihat dokumentasi atau .envbackup)."
  exit 1
fi

# Load env vars dari .env tanpa mengeksekusi nilai sebagai shell command.
# Format yang didukung: KEY=value (komentar dan baris kosong diabaikan).
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Validasi env vars wajib.
: "${SUPABASE_URL:?SUPABASE_URL belum diset di .env}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY belum diset di .env}"
GOOGLE_SHEETS_API_KEY="${GOOGLE_SHEETS_API_KEY:-}"

DEVICE="${1:-chrome}"

echo "==> Menjalankan flutter run di device: $DEVICE"
echo "==> Supabase URL: $SUPABASE_URL"

EXTRA_FLAGS=()
if [[ "$DEVICE" == "chrome" ]]; then
  # Disable web security agar fetch ke image-proxy / Supabase tidak
  # diblokir CORS di lokal (mirroring instruksi di docs/10-cara-menjalankan.md).
  EXTRA_FLAGS+=(--web-browser-flag "--disable-web-security")
fi

exec flutter run \
  -d "$DEVICE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_SHEETS_API_KEY="$GOOGLE_SHEETS_API_KEY" \
  "${EXTRA_FLAGS[@]}"
