#!/usr/bin/env bash
# Deploys deploy/compose.yml as Dokploy compose service "termin" (project "termin") on skdevserver1.
# Idempotent: finds or creates project + compose, pushes the compose file (source type raw, same pattern as
# Stoicera/werkbank-site) and the env rendered by `op inject` (never written to disk),
# deploys, and waits for the deployment record. Needs: op (vault Agents), jq, curl.
#   scripts/deploy-dokploy.sh            # update + deploy
#   scripts/deploy-dokploy.sh --no-deploy  # update config only
set -euo pipefail
cd "$(dirname "$0")/.."
DOKPLOY_URL=${DOKPLOY_URL:-https://dokploy.kernsebastian.com}
SERVER_NAME=${SERVER_NAME:-Hetzner VPS SKDEV1}     # = skdevserver1; checked by name, never the panel's local server
PROJECT=termin; COMPOSE=termin
KEY=$(op read 'op://Agents/Dokploy API/credential')
api() {  # api GET path | api POST path json
  local m=$1 p=$2; shift 2
  curl -fsS -X "$m" -H @<(printf 'x-api-key: %s\n' "$KEY") -H 'content-type: application/json' "$@" "$DOKPLOY_URL/api/$p"
}

server_id=$(api GET server.all | jq -r --arg n "$SERVER_NAME" '.[] | select(.name==$n) | .serverId')
[ -n "$server_id" ] || { echo "server '$SERVER_NAME' not found" >&2; exit 1; }

env_id=$(api GET project.all | jq -r --arg p "$PROJECT" '.[] | select(.name==$p) | .environments[] | select(.name=="production") | .environmentId' | head -1)
if [ -z "$env_id" ]; then
  api POST project.create --data "$(jq -nc --arg n "$PROJECT" '{name:$n, description:"Cal.diy Termin (termin.stoicera.com), repo Stoicera/termin"}')" >/dev/null
  env_id=$(api GET project.all | jq -r --arg p "$PROJECT" '.[] | select(.name==$p) | .environments[] | select(.name=="production") | .environmentId' | head -1)
  echo "project $PROJECT: angelegt"
fi
[ -n "$env_id" ] || { echo "no production environment in project $PROJECT" >&2; exit 1; }

compose_id=$(api GET project.all | jq -r --arg p "$PROJECT" --arg c "$COMPOSE" '.[] | select(.name==$p) | .environments[].compose[]? | select(.name==$c) | .composeId' | head -1)
if [ -z "$compose_id" ]; then
  api POST compose.create --data "$(jq -nc --arg n "$COMPOSE" --arg e "$env_id" --arg s "$server_id" \
    '{name:$n, environmentId:$e, serverId:$s, composeType:"docker-compose", description:"Cal.diy + PostgreSQL 16, compose from Stoicera/termin deploy/compose.yml"}')" >/dev/null
  compose_id=$(api GET project.all | jq -r --arg p "$PROJECT" --arg c "$COMPOSE" '.[] | select(.name==$p) | .environments[].compose[]? | select(.name==$c) | .composeId' | head -1)
  echo "compose $COMPOSE: angelegt ($compose_id)"
fi
actual_server=$(api GET "compose.one?composeId=$compose_id" | jq -r .serverId)
[ "$actual_server" = "$server_id" ] || { echo "compose $compose_id runs on $actual_server, expected $server_id — stop" >&2; exit 1; }

# Compose file + env in one update; the env goes from op inject straight into the request body.
op inject -i deploy/cal.env.tpl | grep -v '^#' | grep -v '^$' \
| jq -Rs --arg id "$compose_id" --rawfile f deploy/compose.yml \
    '{composeId:$id, sourceType:"raw", composeFile:$f, composePath:"./docker-compose.yml", env:., autoDeploy:false}' \
| api POST compose.update --data @- >/dev/null
echo "compose $COMPOSE ($compose_id): Datei und Env aktualisiert, Server $SERVER_NAME"

[ "${1:-}" = "--no-deploy" ] && exit 0
before=$(api GET "deployment.allByCompose?composeId=$compose_id" | jq 'length')
api POST compose.deploy --data "$(jq -nc --arg id "$compose_id" '{composeId:$id}')" >/dev/null
echo "deploy angestoßen, warte auf den Deployment-Eintrag …"
for _ in $(seq 1 90); do
  sleep 10
  d=$(api GET "deployment.allByCompose?composeId=$compose_id")
  [ "$(jq 'length' <<<"$d")" -gt "$before" ] || continue
  status=$(jq -r 'sort_by(.createdAt) | last | .status' <<<"$d")
  case $status in
    done)  echo "deployment: done"; exit 0 ;;
    error) echo "deployment: error — log: $(jq -r 'sort_by(.createdAt) | last | .logPath' <<<"$d") on the node" >&2; exit 1 ;;
  esac
done
echo "deployment did not finish within 15 minutes" >&2; exit 1
