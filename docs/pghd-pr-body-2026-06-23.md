# PR: PGHD Activity Events to Reviewed Encounter Drafts

## Summary

This change completes the PGHD handoff path from provider-originated activity
events to reviewed PhysioApp encounter-note drafts.

- Add `pghd_activity_events` as the generic PGHD source/staging layer.
- Keep `run_log_runs` as the running-specific projection.
- Materialize weekly activity-derived human state into `human_state_snapshots`.
- Track provenance through `human_state_snapshot_inputs.pghd_activity_event_id`.
- Expose encounter insight `sourceActivities`.
- Export encounter-note drafts only, with PGHD provenance preserved.
- Show `PGHD evidence` in PhysioApp before the professional saves the draft.

## Safety

- PGHD is not written directly to finalized clinical notes.
- Run-log produces draft exports only.
- PhysioApp persists through its authenticated encounter note workflow.
- Drafts remain `status = draft`.
- Professionals can inspect source activity evidence before saving.
- Provenance is retained in `encounter_notes.ai_draft_snapshot`.

## Architecture Notes

This does not add duplicate PhysioApp snapshot/context/memory/timeline tables.
PhysioApp already has:

- `chat_context_snapshots`
- `client_memory_chunks`
- `patient_clinical_state`
- `person_lifecycle_events`

`pghd_activity_events` remains the provider-originated source layer and feeds
the existing PhysioApp projections/workflows.

## Migration

- Broad `supabase db push` from `strava-run-log` remains blocked.
- Remote schema was applied only through the PhysioApp owner-lineage path.
- Focused post-apply SQL check passed.
- Single owner migration version `20260623051621` was marked applied after the
  focused check.
- Remote smoke now passes:
  - `npm run check:pghd:status`
  - `npm run check:pghd:smoke-cleanup`
  - `npm run check:pghd:migration-history`

## Evidence

Run-log:

- `npm test`: 150 passed
- `npm run check:pghd:status`: passed
- `npm run check:pghd:smoke-cleanup`: passed
- `npm run check:pghd:migration-history`: passed
- Vercel preview deployment: passed
- `git diff --check`: passed

PhysioApp:

- Consumer PR merged: <https://github.com/Youngkwon-Lee/physio_app/pull/354>
- `pnpm run test:e2e:pghd-note-draft`: 3 passed in 2.7 minutes
- PGHD component/server/client Jest tests: passed
- PGHD consume route Jest test: passed
- targeted `eslint`: exit 0, existing warnings only
- `git diff --check`: passed

## Remaining Debt

Older local Run-log PGHD migration versions remain intentionally unrepaired in
remote migration history. Do not broad-repair them in this PR. The required
schema is present and verified through owner-lineage apply plus remote smoke.

## Supporting Docs

- `docs/pghd-pr-summary-2026-06-23.md`
- `docs/pghd-pr-evidence-2026-06-23.md`
