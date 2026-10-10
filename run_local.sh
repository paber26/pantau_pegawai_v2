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
#   - Edit file `.env` untuk mengganti API_URL atau GOOGLE_SHEETS_API_KEY.
#   - API lokal: lihat docs/10-cara-menjalankan.md (folder server/).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE tidak ditemukan."
  echo "Buat file .env terlebih dahulu (salin dari .env.example)."
  exit 1
fi

# Load env vars dari .env tanpa mengeksekusi nilai sebagai shell command.
# Format yang didukung: KEY=value (komentar dan baris kosong diabaikan).
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Validasi env vars wajib.
: "${API_URL:?API_URL belum diset di .env}"
GOOGLE_SHEETS_API_KEY="${GOOGLE_SHEETS_API_KEY:-}"

DEVICE="${1:-chrome}"

echo "==> Menjalankan flutter run di device: $DEVICE"
echo "==> API URL: $API_URL"

# CORS untuk http://localhost:* diatur di API (CORS_ORIGINS), jadi Chrome
# tidak perlu lagi dijalankan dengan --disable-web-security.
exec flutter run \
  -d "$DEVICE" \
  --dart-define=API_URL="$API_URL" \
  --dart-define=GOOGLE_SHEETS_API_KEY="$GOOGLE_SHEETS_API_KEY"
