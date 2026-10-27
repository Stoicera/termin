# Termin — Agent Context

Read the Stoicera SSOT `ai/CONTEXT.md` first. This repo builds and runs Cal.diy (MIT, upstream `calcom/cal.diy`) for "Termin buchen" at termin.stoicera.com. Goal: core/26 Ziel 1 (content → booked call → offer).

- Image: built only in GitHub Actions (`.github/workflows/build.yml`, input = full upstream commit SHA) → `ghcr.io/stoicera/termin-cal:<sha>`. Never build on the app node (upstream sets `--max-old-space-size=6144`).
- Run: Dokploy compose `termin` on skdevserver1, `deploy/compose.yml`, env from `deploy/cal.env.tpl` via `op inject` (vault `Agents`), `scripts/deploy-dokploy.sh`.
- Signup is closed twice: `NEXT_PUBLIC_DISABLE_SIGNUP=true` at build time and a Traefik 403 router.
- Backup: `scripts/backup.sh` (pg_dump nightly 02:50 UTC, restic, backupsink). Bookings are personal data — never on a laptop.
- Rebuild monthly and on every security advisory of `calcom/cal.diy`. Runbook: `docs/runbook.md`.
- Gate `direct`. Commits in German. After any production change: one line in SSOT `ops/runlog.md`.
