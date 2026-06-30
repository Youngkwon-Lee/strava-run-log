# PGHD Activity Events PR Evidence

Date: 2026-06-23

Status update: PhysioApp consumer PR #354 merged, and Run-log PR #1 Vercel
preview now passes after consolidating deployed API functions under catch-all
routes.

## Migration Path

- Broad `supabase db push` from `strava-run-log` remains forbidden.
- Apply only through the PhysioApp owner-lineage migration path.
- Owner-lineage migration staged at:
  - `/Users/youngkwon/projects/physio_app/supabase/migrations/20260623051621_add_pghd_activity_events_layer.sql`
- Source integration migration in this repo:
  - `supabase/migrations/20260623033034_add_pghd_activity_events_layer.sql`
- Remote owner-lineage apply completed through the PhysioApp pooler helper:
  - `node scripts/apply-live-migration-via-pooler.mjs supabase/migrations/20260623051621_add_pghd_activity_events_layer.sql`
- Migration history was repaired only for the applied owner-lineage version:
  - `supabase migration repair 20260623051621 --status applied --linked --workdir /Users/youngkwon/projects/physio_app --yes`

## Duplication Check

PhysioApp already has the higher-level runtime/read layers that this PGHD source
event layer should feed:

- `chat_context_snapshots`: existing LLM/read-context snapshot layer.
- `client_memory_chunks`: existing long-term client memory layer.
- `patient_clinical_state`: existing current clinical state summary layer.
- `person_lifecycle_events` plus timeline helpers: existing timeline source/read
  path.

Do not add new tables named `encounter_room_snapshots`, `session_contexts`,
`client_memories`, `clinical_state_summaries`, or `timeline_read_models` for
this PR. `pghd_activity_events` is only the provider-originated PGHD source
activity layer. It links forward into existing projections through:

- `run_log_runs.pghd_activity_event_id`
- `human_state_snapshot_inputs.pghd_activity_event_id`
- encounter insight `sourceActivities`

## Local Evidence

- `npm test`
  - Result: pass
  - Evidence: 150 tests passed
- `node --test test/dashboard-html.test.js`
  - Result: pass
  - Evidence: dashboard inline scripts compile and PGHD evidence UI strings are present
- `git diff --check`
  - Result: pass
- Vercel preview
  - Result: pass
  - Evidence: deployed API functions were reduced from 20 to 8 to stay within
    the Hobby plan serverless function limit.

## PhysioApp Consumer Evidence

- Consumer PR:
  - URL: <https://github.com/Youngkwon-Lee/physio_app/pull/354>
  - Result: merged
- `pnpm run test:e2e:pghd-note-draft`
  - Working directory: `/Users/youngkwon/projects/physio_app`
  - Result: pass
  - Evidence: 3 Playwright tests passed in 2.7 minutes.
  - Covered flows:
    - pasted Run-log draft export from desktop encounter room
    - configured Run-log server proxy import
    - pasted Run-log draft export from mobile encounter room
- PhysioApp UI now shows `PGHD evidence` in the draft handoff panel from
  `ai_draft_snapshot.pghd_insight.sourceActivities`.
- PhysioApp E2E validates persisted `encounter_notes.ai_draft_snapshot` retains
  the expected `pghdActivityEventId`.

## Remote Smoke

Owner-lineage migration was applied remotely on 2026-06-23.

Focused post-apply database check passed:

```bash
cd /Users/youngkwon/projects/physio_app
node scripts/check-pghd-run-log-bridge-live.mjs scripts/sql/check-pghd-activity-events-layer.sql
```

Evidence:

```text
check_name                         | activity_events_table | ok
pghd_activity_events_layer_ready   | pghd_activity_events  | t
```

Remote smoke commands were retried from `strava-run-log` after Supabase remote
schema cache recovered:

- `npm run check:pghd:status`
  - Result: pass
  - Evidence: state schema readiness passed on attempt 1; state DB smoke passed; state materialization smoke passed with `materializedCount: 3`, `readBackCount: 3`, and `inputLinkCount: 3`.
- `npm run check:pghd:smoke-cleanup`
  - Result: pass
  - Evidence: `leftoverBootstrapConnections: 0`, `leftoverSmokeRuns: 0`, `activeSmokePersons: 0`.
- `npm run check:pghd:migration-history`
  - Result: pass on retry.
  - Evidence: `ok: true`, `ownerBridgeApplied: true`, `dbPushBlocked: true`.
  - Note: local run-log PGHD migration versions `20260622014705`, `20260622023954`, `20260622040100`, `20260622043000`, and `20260622145528` remain pending in remote migration history; do not repair them until schema and smoke checks prove those older SQL changes are already present remotely.

The focused pooler SQL postcheck and remote smoke now confirm:

- `public.pghd_activity_events` exists.
- `public.run_log_runs.pghd_activity_event_id` exists.
- `public.human_state_snapshot_inputs.pghd_activity_event_id` exists.
- state materialization can write/read snapshots and input provenance.
- cleanup reports no leftover PGHD smoke artifacts.
