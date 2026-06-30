# PGHD Activity Events PR Summary

Date: 2026-06-23

## Scope

This PR completes the PGHD handoff path from provider activity data to reviewed
encounter-note draft:

```text
Apple Watch / Strava / Apple Health
-> pghd_connections
-> pghd_activity_events
-> run_log_runs
-> run_log_weekly_summaries
-> human_state_snapshots
-> human_state_snapshot_inputs
-> encounter insights sourceActivities
-> encounter_notes draft export
-> PhysioApp professional review
```

## Safety Boundary

- PGHD does not write directly into finalized clinical notes.
- Run-log generates a draft export only.
- PhysioApp persists the draft through its authenticated encounter note workflow.
- `status` remains `draft` until a professional reviews/signs off.
- `pghdActivityEventId` provenance is retained in `ai_draft_snapshot`.

## Duplication Decision

Do not add new PhysioApp tables for:

- `encounter_room_snapshots`
- `session_contexts`
- `client_memories`
- `clinical_state_summaries`
- `timeline_read_models`

PhysioApp already has equivalent higher-level layers:

- `chat_context_snapshots`
- `client_memory_chunks`
- `patient_clinical_state`
- `person_lifecycle_events`

`pghd_activity_events` is only the provider-originated PGHD source/staging
layer. It feeds the existing state, insight, note, context, memory, and timeline
paths instead of replacing them.

## Migration Path

- Broad `supabase db push` from `strava-run-log` remains blocked.
- Remote schema was applied through the PhysioApp owner-lineage path only.
- Applied owner migration:
  `/Users/youngkwon/projects/physio_app/supabase/migrations/20260623051621_add_pghd_activity_events_layer.sql`
- Source repo migration:
  `supabase/migrations/20260623033034_add_pghd_activity_events_layer.sql`
- Focused post-apply check passed:
  `node scripts/check-pghd-run-log-bridge-live.mjs scripts/sql/check-pghd-activity-events-layer.sql`

## Run-Log Evidence

- `npm test`
  - Result: pass
  - Evidence: 150 tests passed
- `npm run check:pghd:status`
  - Result: pass
  - Evidence: state schema, state DB smoke, and state materialization smoke passed.
- `npm run check:pghd:smoke-cleanup`
  - Result: pass
  - Evidence: no leftover bootstrap connections, smoke runs, or active smoke persons.
- `git diff --check`
  - Result: pass

## PhysioApp Evidence

- `pnpm run test:e2e:pghd-note-draft`
  - Result: pass
  - Evidence: 3 Playwright tests passed in 2.7 minutes.
  - Covered desktop pasted draft export, configured Run-log proxy import, and mobile pasted draft export.
- PGHD handoff Jest tests
  - Result: pass
  - Evidence: component/server/client/route tests pass.
- targeted `eslint`
  - Result: exit 0
  - Note: existing `encounter-room.tsx` warnings remain; no errors.
- `git diff --check`
  - Result: pass

## Remaining Migration-History Debt

`npm run check:pghd:status` reports:

- `ownerBridgeApplied: true`
- `dbPushBlocked: true`
- `recommendedApplyPath: physio-app-owner-lineage`
- old local PGHD migration versions remain pending in remote history:
  - `20260622014705`
  - `20260622023954`
  - `20260622040100`
  - `20260622043000`
  - `20260622145528`

Do not broad-repair these in this PR. The required schema is already present and
verified through owner-lineage apply plus smoke tests. Repairing older local
history should be a separate reconciliation task with its own proof.

## Reviewer Notes

- Review Run-log source/state/insight changes separately from PhysioApp consumer
  UI changes.
- In PhysioApp, the intentional PGHD files are:
  - `src/features/encounter-room/components/encounter-room.tsx`
  - `src/features/encounter-room/components/pghd-note-draft-handoff-panel.tsx`
  - `src/features/encounter-room/components/__tests__/pghd-note-draft-handoff-panel.test.tsx`
  - `src/features/encounter-room/server/__tests__/pghd-note-draft-handoff.test.ts`
  - `src/app/api/app/encounters/[encounterId]/pghd-note-draft/__tests__/route.test.ts`
  - `e2e/pghd-note-draft-handoff.verify.spec.ts`
  - `scripts/pghd-run-log-fixture.mjs`
  - `supabase/migrations/20260623051621_add_pghd_activity_events_layer.sql`
  - `docs/db/PGHD_ACTIVITY_EVENTS_LAYER_2026-06-23.md`
  - `scripts/sql/check-pghd-activity-events-layer.sql`
