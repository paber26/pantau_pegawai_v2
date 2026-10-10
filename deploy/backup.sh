#!/bin/sh
# Backup harian database dengan pg_dump (format custom, bisa di-restore
# dengan pg_restore). File lama dihapus setelah BACKUP_KEEP_DAYS hari.
# Salin folder ./backups ke luar VPS secara berkala (mis. rsync/scp).
set -eu

KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"

while true; do
  FILE="/backups/pantau_$(date +%Y%m%d_%H%M%S).dump"
  if pg_dump --format=custom --file="$FILE.tmp"; then
    mv "$FILE.tmp" "$FILE"
    echo "$(date -Iseconds) backup OK: $FILE"
  else
    rm -f "$FILE.tmp"
    echo "$(date -Iseconds) backup GAGAL" >&2
  fi
  find /backups -name 'pantau_*.dump' -mtime +"$KEEP_DAYS" -delete
  sleep 86400
done
