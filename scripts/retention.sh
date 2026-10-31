#!/usr/bin/env bash
# Deletes Cal bookings twelve months after the appointment (privacy notice stoicera.com/datenschutz#terminbuchung
# and werkbank.stoicera.com/datenschutz, 31.10.2026). Attendees, references and notes go with them (FK cascade).
# Install as /opt/termin/scripts/retention.sh; reads COMPOSE_PROJECT from /opt/termin/backup.env.
# Cron /etc/cron.d/termin-retention:  15 3 1 * * root /opt/termin/scripts/retention.sh >> /var/log/termin-retention.log 2>&1
# Bookings that became a contract are copied to the customer file before; this script does not know about contracts.
#   retention.sh --dry-run   counts only
set -euo pipefail
# shellcheck source=/dev/null
. /opt/termin/backup.env
db=$(docker ps -q -f "label=com.docker.compose.project=$COMPOSE_PROJECT" -f "label=com.docker.compose.service=cal-db")
[ -n "$db" ] || { echo "cal-db container not found" >&2; exit 1; }

where="\"endTime\" < now() - interval '12 months'"
if [ "${1:-}" = "--dry-run" ]; then
  n=$(docker exec "$db" psql -U cal -d cal -Atc "select count(*) from \"Booking\" where $where")
  echo "$(date -u +%FT%TZ) termin retention dry-run: $n bookings older than 12 months"
  exit 0
fi
n=$(docker exec "$db" psql -U cal -d cal -Atc "with d as (delete from \"Booking\" where $where returning 1) select count(*) from d")
echo "$(date -u +%FT%TZ) termin retention: $n bookings deleted"
