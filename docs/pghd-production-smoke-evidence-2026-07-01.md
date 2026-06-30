# PGHD Production Smoke Evidence - 2026-07-01

Environment:
- Base URL: `https://strava-run-log.vercel.app`
- Local time: `2026-07-01 06:39:58-06:40:08 KST`
- Command: `npm run smoke:production`
- Token source: ignored local secret file, value not recorded

Result:
- `ok: true`
- Dashboard PGHD surfaces loaded from production
- Unauthenticated `POST /api/live/metrics` returned `401`
- Unauthenticated `POST /api/apple-health/ingest` returned `401`
- Authenticated `GET /api/run-log/preflight` passed
- Production Vercel error logs were empty for the checked window
- Production Vercel warning logs were empty for the checked window

Preflight evidence:
- Subject: `22222222...2222`
- PGHD connection: `748ecfc8...dd65`
- Selection mode: `existing_apple_health_with_org_client_context`
- Org-client context: `true`
- Summary: `ok`

Preflight checks:
- `run_store_backend`: `ok`
- `physio_person_context`: `ok`
- `connection_mapping`: `ok`
- `activity_ingest`: `ok`
- `weekly_summary`: `ok`
- `state_materialization`: `ok`

Notes:
- No broad `supabase db push` was run.
- No production token value was printed or committed.
