# Runbook — Cal.diy "Termin buchen" (termin.stoicera.com) — prepared, not deployed

Goal: `core/26` Ziel 1 (one CTA "Termin buchen" for everything). Source prompt: SSOT `ai/prompts/deploy-cal.md` (15.10.2026). State 2026-10-21: templates in `deploy/cal/`, nothing running. Decision 2026-10-21 (orchestrator): Ghost first; Cal waits for its open human steps and a week of real Ghost memory numbers.

## Facts re-checked 2026-10-21

- `calcom/cal.com` → `calcom/cal.diy`, licence MIT, last push 2026-10-19. `main` = `0f19cc46ef6b6426ee398c670575b3c96be7af9e` (86 checks success, 14 skipped) — pinned in `deploy/cal/build.yml` and `deploy/cal/compose.yml`.
- The Dockerfile still sets `MAX_OLD_SPACE_SIZE=6144` and has `ENV NEXT_PUBLIC_WEBAPP_URL=` first in the builder stage, so the signup-closing `sed` in `build.yml` applies unchanged. Build in GitHub Actions only, never on the app node.
- `postgres:16.15-alpine` is still the newest 16.x.
- Host: skdevserver1 had 5035 MB available before Ghost (2026-10-21) → by the rule Ghost and Cal both fit. Re-measure after Ghost has run a week; Cal only if ≥ 2 GB remain.

## Files

| File | Becomes |
|---|---|
| `deploy/cal/build.yml` | `.github/workflows/build.yml` in `Stoicera/termin` (workflow_dispatch, GHCR `ghcr.io/stoicera/termin-cal:<commit>`, Trivy report) |
| `deploy/cal/compose.yml` | `deploy/compose.yml` there; Dokploy compose `termin` on skdevserver1, same raw-source pattern as `scripts/deploy-dokploy.sh` |
| `deploy/cal/cal.env.tpl` | env via `op inject` into the Dokploy API |
| `deploy/cal/backup.sh` | `/opt/termin/scripts/backup.sh`, cron 02:50 UTC, restic + `offsite-sync.sh` |

## Human steps (in this order)

| Nr | Who | Step |
|---|---|---|
| C0 | Org owner (Sebastian) | Create the **public** repo `Stoicera/termin` (MIT notice pointing to upstream); the agent then copies `deploy/cal/*` into it and runs the build once |
| C1 | — | ssh + Dokploy API key: done 2026-10-21 (shared with Ghost) |
| C2 | Agent with the `Cloudflare` token, Sebastian checks | A `termin` → skdevserver1, grey until the certificate exists, then proxied; rate-limit rule `/api/auth`, `/api/book` 20 req / 10 s per IP; WAF block for `/signup` |
| C3 | Sebastian | Resend: second send-only key `termin-smtp` on `mail.stoicera.com` (needs Ghost E4 first), in `Agents/Resend SMTP Termin` |
| C4 | Sebastian, **right after the first healthy start** | `https://termin.stoicera.com/auth/setup` → admin account sebastian.kern@stoicera.com, username `sebastian`, own password, 2FA. Until then anyone could run the setup |
| C5 | Sebastian — **the one question that changes the build** | Where do your appointments actually live: Google or Zoho calendar? Google → OAuth client (redirect `https://termin.stoicera.com/api/integrations/googlecalendar/callback`, status "In production"); Zoho → `zohocalendar` app with a Zoho API Console client |
| C6 | Sebastian | Availability (proposal Mon–Fri 09–12 and 14–16 Europe/Vienna) and the Zoho Meet room link |
| C7 | Sebastian | Privacy notice stoicera.com/datenschutz: section "Terminbuchung" (purpose, legal basis, retention, recipients Resend and Google or Zoho) before the first public link |
| C8 | Sebastian, Raphael | Release the links in CTAs only after the browser booking test |

## Agent commands once C0 exists

```bash
gh repo clone Stoicera/termin ~/Work/stoicera/termin && cd ~/Work/stoicera/termin
mkdir -p .github/workflows deploy scripts docs
cp ../werkbank-site/deploy/cal/build.yml .github/workflows/build.yml
cp ../werkbank-site/deploy/cal/compose.yml deploy/compose.yml
cp ../werkbank-site/deploy/cal/cal.env.tpl deploy/cal.env.tpl
cp ../werkbank-site/deploy/cal/backup.sh scripts/backup.sh
git add -A && git commit -m "Cal.diy-Bau und Deploy-Vorlagen aus werkbank-site" && git push
gh workflow run build-cal -f cal_ref=0f19cc46ef6b6426ee398c670575b3c96be7af9e && gh run watch
docker logout ghcr.io; docker pull ghcr.io/stoicera/termin-cal:0f19cc46ef6b6426ee398c670575b3c96be7af9e   # anonymous pull must work

# secrets (three different values, never rotate encryption_key without a plan)
jq -n --arg a "$(openssl rand -hex 32)" --arg b "$(openssl rand -base64 32)" --arg c "$(openssl rand -base64 24)" \
  '{title:"Termin Cal",category:"SECURE_NOTE",fields:[{id:"db_password",label:"db_password",type:"CONCEALED",value:$a},{id:"nextauth_secret",label:"nextauth_secret",type:"CONCEALED",value:$b},{id:"encryption_key",label:"encryption_key",type:"CONCEALED",value:$c}]}' \
  | cat | op item create --vault Agents -
# then: a copy of scripts/deploy-dokploy.sh with PROJECT/COMPOSE=termin and deploy/cal.env.tpl, steps 5–11 of the SSOT prompt
```

Rollback and runlog template: SSOT `ai/prompts/deploy-cal.md`.
