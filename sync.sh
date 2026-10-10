#!/usr/bin/env bash
#
# sync.sh — sinkronisasi data dari Google Spreadsheet (AppSheet lama) ke
# database PantauPegawai di VPS.
#
# Menjalankan server/scripts/migrate-from-sheets.ts di dalam container `api`.
# Aman dijalankan berkali-kali karena script melakukan deduplikasi otomatis
# berdasarkan (user_id, tanggal_kegiatan, proyek).
#
# Pemakaian (di VPS, dari folder repository yang berisi docker-compose.yml):
#   ./sync.sh
#
# Kebutuhan:
#   - Stack sudah berjalan (docker compose up -d)
#   - GOOGLE_SHEETS_API_KEY sudah diisi di file .env

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Menjalankan sinkronisasi data dari Google Spreadsheet..."
echo ""

docker compose exec api node dist/scripts/migrate-from-sheets.js
