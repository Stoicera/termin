#!/usr/bin/env bash
# Nightly backup of Cal "Termin" on skdevserver1 (template; install as /opt/termin/scripts/backup.sh once Cal runs).
# Config /opt/termin/backup.env (root, 0600): COMPOSE_PROJECT=<Dokploy appName of compose "termin">  KEEP_DAYS=14
# Cron /etc/cron.d/termin-backup:  50 2 * * * root /opt/termin/scripts/backup.sh >> /var/log/termin-backup.log 2>&1
# Bookings are personal data of prospects: only on the node, on backupsink and in the encrypted restic repo.
set -euo pipefail
. /opt/termin/backup.env
OUT=/var/backups/termin
TS=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$OUT"; chmod 700 "$OUT"

db=$(docker ps -q -f "label=com.docker.compose.project=$COMPOSE_PROJECT" -f "label=com.docker.compose.service=cal-db")
[ -n "$db" ] || { echo "cal-db container not found" >&2; exit 1; }
docker exec "$db" pg_dump -U cal -Fc cal > "$OUT/cal-$TS.dump"
docker exec -i "$db" pg_restore --list < "$OUT/cal-$TS.dump" >/dev/null   # archive is readable
( cd "$OUT" && sha256sum "cal-$TS.dump" > "cal-$TS.dump.sha256" )

ls "$OUT"/*.dump >/dev/null 2>&1 || { echo "backup dir empty" >&2; exit 1; }
find "$OUT" -name 'cal-*' -mtime +"$KEEP_DAYS" -delete
echo "$(date -u +%FT%TZ) termin backup ok: $(du -sh "$OUT/cal-$TS.dump" | cut -f1)"

OFFSITE_SUBDIR=termin OFFSITE_PATTERN='cal-*.dump' /opt/einvoice-at/scripts/offsite-sync.sh "$OUT"
