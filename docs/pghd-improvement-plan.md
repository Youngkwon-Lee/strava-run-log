# PGHD Run Log Improvement Plan

Last checked: 2026-06-23

## Current State

The run-log PGHD state path is functionally ready, but the linked Supabase
migration history is not ready for normal `supabase db push` from this repo.
For the operator-ready command sequence, gate matrix, and release decision
template, see [`pghd-execution-roadmap.md`](pghd-execution-roadmap.md).

Verified locally:

- `npm test` passes.
- `npm run check:pghd:state-functional` passes.
- `npm run check:pghd:status` reports `preflightSurfaceOk: true` and
  `functionalOk: true`.
- `npm run check:pghd:status` now passes through the PhysioApp owner-lineage
  bridge, while still reporting `localMigrationHistoryOk: false` and
  `dbPushBlocked: true`.

Verified against the linked Supabase project:

- `run_log_runs` exposes the activity-event columns required by this repo.
- `human_state_snapshots` exists and accepts state snapshot rows.
- `human_state_snapshot_inputs` exists and preserves traceability to source run rows.
- Weekly state materialization writes and reads back persisted snapshots.

Known residual migration debt:

- `npm run check:pghd:migration-history` reports `dbPushBlocked: true`.
- The linked project has hundreds of remote migration history entries that are
  not present in `strava-run-log`.
- The same command prints operator `nextActions`: fetch linked remote history
  before repairing PGHD local-only versions as applied.

## Migration Ownership Finding

The remote-only migration history is owned by the PhysioApp migration lineage,
not by this lightweight run-log repo.

Local evidence:

- `/Users/youngkwon/Projects/physio_app/supabase/migrations` contains hundreds
  of migrations, including the remote-only samples reported by this repo such as
  `20260215234342`, `20260215235103`, and `20260621033128`.
- `/Users/youngkwon/Projects/physio_app/docs/db/SUPABASE_MIGRATION_REPAIR_BATCH_2_CLASSIFICATION_2026-05-20.md`
  documents historical migration repair and explicitly treats the early
  `20260215...` remote-only range as PhysioApp lineage, not disposable remote
  junk.
- `/Users/youngkwon/Projects/physio_app/docs/db/SOCCER_PERFORMANCE_MVP_WAVE1_2026-06-21.md`
  documents a later live migration where history was repaired after postcheck.

Decision:

- Do not run broad `supabase migration repair` from `strava-run-log`.
- Treat this repo's migration files as an integration patch that must be ported
  into the PhysioApp-owned migration lineage or applied through a deliberate
  PhysioApp repair workflow.

## Phase 0: Freeze The Working Functional Path

Objective: keep the currently working PGHD state path reviewable and protected.

Exit checks:

```bash
npm test
npm run check:pghd:state-functional
npm run smoke:pghd
```

Notes:

- `check:pghd:status` is allowed to fail while `migrationHistoryOk` is false.
- Direct SQL fallback is only for functional schema recovery. It is not a
  migration history fix.

## Phase 1: Reconcile Through The Owning Repo

Objective: move the run-log PGHD migration into the repo that owns the linked
Supabase history.

Progress:

- Added PhysioApp migration
  `/Users/youngkwon/Projects/physio_app/supabase/migrations/20260622162503_add_pghd_run_log_activity_state_bridge.sql`.
- Added PhysioApp DB note
  `/Users/youngkwon/Projects/physio_app/docs/db/PGHD_RUN_LOG_ACTIVITY_STATE_BRIDGE_2026-06-23.md`.
- Applied the bridge SQL through the PhysioApp pooler path and marked only
  `20260622162503` as applied in Supabase migration history after focused
  postchecks passed.
- `npm run check:pghd:status` now passes with `ownerBridgeApplied: true`.
- The PhysioApp migration ports the full run-log schema intent, not only the
  final state snapshot migration, because `run_log_runs` is not present in the
  PhysioApp lineage before this bridge.
- The migration also extends `pghd_connections_provider_check` for `strava` and
  hyphenated bridge provider slugs.
- PhysioApp linked `db push --dry-run` is still blocked before this bridge by
  remote-only versions `20260521053152` and `20260521094500`; normal `db push`
  is not currently a single-bridge apply path.

Recommended path:

1. Review the new PhysioApp bridge migration against the existing PhysioApp
   DataOps projection migration.
2. Apply the bridge through the existing exact-file live migration path if it
   must ship before full migration normalization.
3. Run focused SQL postchecks, then mark only `20260622162503` applied through
   the established PhysioApp repair workflow.
4. Return to `strava-run-log` and rerun:

```bash
npm run check:pghd:status
```

Exit condition:

- `functionalOk: true`
- `migrationHistoryOk: true`
- `ownerBridgeApplied: true`

Expected residual condition:

- `localMigrationHistoryOk: false`
- `dbPushBlocked: true`

That residual condition means `strava-run-log` still must not use broad
`supabase db push` against the linked project. It does not block the accepted
owner-lineage bridge path.

## Phase 2: Product Surface

Objective: make the app read as a PGHD state timeline, not a Strava activity
clone.

Progress:

- Added a first-screen `PGHD Review Brief` above the WHO/raw run cards.
- The brief summarizes current training load, fatigue, adherence, and the
  highest-priority encounter insight before the raw activity list.
- The dashboard now keeps the current Human State section ahead of weekly
  activity evidence and raw timeline details.
- Each Human State card now exposes a collapsible source activity traceability
  section using the snapshot `inputs` run ids and weights.
- `GET/POST /api/run-log/state-snapshots` now enriches `inputs` with compact
  source activity summaries from `run_log_runs`, including name, date, distance,
  moving time, pace, heart rate, and device when available.
- Empty states now distinguish missing current state, missing state signals,
  missing encounter insights, missing weekly evidence, and missing timeline
  records, with operator guidance for mapping/ingest checks.
- Empty API responses now include `emptyReason`, `emptyMessage`,
  `operatorHints`, and `emptyScope`; the dashboard uses these fields to show
  source-specific mapping/ingest guidance instead of only static empty copy.
- Added `GET /api/run-log/preflight` and a dashboard `PGHD 운영 점검` panel to
  check PhysioApp person/org-client context, connection mapping, provider
  ingest, weekly summaries, and state materialization in one operator-facing
  response.
- `npm run smoke:pghd` now calls `GET /api/run-log/preflight` after ingest and
  weekly summary verification, so live smoke catches readiness regressions.
- Added `pnpm run smoke:dashboard:viewport`, a dependency-free Chrome headless
  smoke that captures desktop and mobile dashboard screenshots and verifies the
  first-screen PGHD review brief/empty-state DOM.
- The preflight endpoint now includes `physio_person_context`, a warning-level
  check that confirms the `subject_person_id` exists in PhysioApp `persons` and
  has `org_clients` context before encounter-room handoff.
- Strict staging smoke can now use
  `npm run smoke:pghd:strict-org-client`
  to create and clean up a temporary PhysioApp org-client subject when no
  reusable PGHD-connected org client exists.
- `npm run smoke:pghd:strict-full` additionally materializes temporary Human
  State snapshots when the preflight gate must prove persisted state, not only
  weekly derived preview signals.
- Dashboard regression tests assert that the PGHD brief appears before WHO
  activity analysis and recent run records, and that state cards surface source
  activity traceability plus specific PGHD empty-state guidance.

Remaining product polish:

- Add richer PhysioApp encounter-context probes once the run-log bridge can
  authenticate against a specific organization/provider session boundary.

Exit checks:

```bash
npm test
```

Plus browser verification of the dashboard at desktop and mobile widths.

## Phase 3: Data Quality And Clinical Semantics

Objective: improve the signal quality before adding more presentation.

Completed:

- Derived weekly state snapshots include confidence and `metadata.dataQuality`.
- Limited or partial signals carry `metadata.insufficientDataReasons`.
- Apple Health and Strava provider source distinctions are preserved through
  the state API and dashboard.
- The dashboard shows data quality and limited-data reasons beside state values.
- Derived weekly state snapshots include `totalKmDelta`, `runCountDelta`,
  `volumeTrend`, and `adherenceTrend` when a prior baseline exists.

Exit checks:

```bash
npm test
npm run smoke:pghd:state
```

## Phase 4: Encounter Insight

Objective: turn current human state into encounter-ready review context while
keeping clinical interpretation under professional review.

Completed:

- Added `GET /api/run-log/encounter-insights`.
- The endpoint prefers persisted `human_state_snapshots` and falls back to
  weekly-derived state when rows are absent or `derive=weekly` is requested.
- Added insight generation for high fatigue/load review, adherence gaps, rapid
  load ramps, data-quality notes, and neutral state review.
- Insight evidence now uses state deltas and trend direction when available, so
  encounter review can distinguish current level from week-over-week change.
- Each insight includes an editable `noteDraft` and the dashboard exposes a
  copy action for professional review before note use.
- Added `POST /api/run-log/encounter-note-drafts` to produce a PhysioApp
  `encounter_notes` draft export row without writing clinical notes directly.
- The draft export now carries an explicit PhysioApp handoff target:
  `createNoteRepository(...).upsert()` from an authenticated server route/action
  using `encounter_id,note_format` as the conflict target.
- The draft export avoids `encounter_notes.data` for PGHD provenance because
  PhysioApp uses that column as DAP text. Provenance is carried in
  `ai_draft_snapshot` and `discipline_sections.pghd_note_draft`; repository
  consumers should use `draftExport.repositoryParams`.
- PhysioApp's note repository now accepts those provenance fields on upsert, so
  `draftExport.repositoryParams` can preserve PGHD source metadata without
  direct table writes.
- PhysioApp now has an authenticated consume route at
  `/api/app/encounters/<encounterId>/pghd-note-draft` that accepts
  `draftExport.repositoryParams` or the full `draftExport` wrapper, verifies the
  note-write role plus encounter context, and saves through
  `createNoteRepository(...).upsert()`.
- PhysioApp also has a feature-local client helper,
  `persistPghdNoteDraftFromRunLogExport`, which posts the payload to that route
  with the required `X-Requested-With` header and typed error handling.
- PhysioApp now has a feature-local `PghdNoteDraftHandoffPanel` component that
  accepts the run-log draft export payload, lets the professional edit
  `note_content`, and saves through `persistPghdNoteDraftFromRunLogExport`
  while preserving the original `repositoryParams`/`draftExport` wrapper shape.
- PhysioApp now mounts a `PghdNoteDraftImportPanel` in `SessionLedger` for the
  current encounter. A professional can paste the run-log full response,
  `draftExport`, or `repositoryParams`, review the note text, and save it
  through the authenticated consume route.
- PhysioApp also mounts the PGHD import surface directly below the encounter
  tabs on desktop and mobile, and inside the mobile AI Copilot sheet, so the
  handoff is reachable from the active encounter room without depending on the
  ledger subsection alone.
- The handoff panel records `review_action = accepted` when unchanged and
  `review_action = modified` when the professional edits the text. The
  authenticated consume route forwards that review action to
  `createNoteRepository(...).upsert()`.
- PhysioApp note provenance display now renders `strava_run_log_pghd` as a
  PGHD state draft label instead of exposing the raw source slug.
- The consume route is covered at route level for authenticated save, auth
  rejection, note-write role rejection, and encounter-context mismatch
  rejection.
- The handoff panel is covered for edited save, full `draftExport` wrapper
  preservation, and route error display.
- The import panel is covered for full run-log response parsing, edited save,
  and invalid JSON display. `SessionLedger` is covered for mounting the PGHD
  note draft import surface on the current encounter.
- Browser verification covers the mounted PhysioApp handoff at desktop and
  mobile widths. The Playwright spec pastes a run-log response JSON, edits the
  note, saves through the authenticated route, and verifies the persisted
  `encounter_notes` row remains `status = draft` with PGHD provenance and
  `review_action = modified`.
- PhysioApp can now fetch a draft export directly from a run-log deployment.
  When server-side `PGHD_RUN_LOG_BASE_URL` plus `PGHD_RUN_LOG_TOKEN` are
  configured, the import panel calls an authenticated PhysioApp proxy route
  instead of exposing the token in the browser. That route loads the latest
  `GET /api/run-log/encounter-insights` result for the encounter subject,
  converts it through `POST /api/run-log/encounter-note-drafts`, and then
  returns the same professional review/save payload. The paste-based JSON
  import and manual URL/token fetch remain fallback and inspection paths.
- PhysioApp can also scope the run-log bridge per organization via
  `organizations.settings.pghd_run_log_bridge`. Supported fields are
  `enabled`, `base_url` or `run_log_base_url`, `default_source`, and
  `token_env_key`. `token_env_key` is allowlisted to
  `PGHD_RUN_LOG_TOKEN`, `RUN_LOG_ADMIN_TOKEN`, or `LIVE_METRICS_TOKEN`; the
  token value itself stays in server env and is not stored in the database or
  sent to the browser.
- PhysioApp settings now include an admin-facing PGHD Run-log bridge panel
  for the non-secret organization fields above. Operators can enable the
  bridge, set the base URL/default source, and choose the server env var name
  that contains the token without entering the secret value in the UI.
- The direct-import path now has a Playwright fixture mode. Running
  `pnpm run test:e2e:pghd-note-draft` starts a local Run-log-compatible
  fixture before the PhysioApp test server, injects `PGHD_RUN_LOG_BASE_URL`
  and `PGHD_RUN_LOG_TOKEN` into the Next.js process, and verifies that the
  encounter room imports and saves a draft through the authenticated
  PhysioApp proxy route.
- The dashboard can now edit an insight note draft and copy the generated
  PhysioApp draft export row when encounter/org/provider ids are supplied.
- The dashboard also shows the generated draft export JSON preview so the
  operator can inspect the row before handing it to PhysioApp.
- The dashboard separately shows and copies `draftExport.repositoryParams` so
  the PhysioApp upsert handoff can use the narrower repository payload instead
  of the fuller row export.
- The dashboard now shows Encounter Insight cards above the weekly activity
  evidence.

Next candidates:

- Add an optional staging-deployment variant of the direct-import E2E for
  testing against a real Run-log environment outside the local fixture. The
  PhysioApp runner already supports this by setting
  `E2E_PGHD_RUN_LOG_FIXTURE=0`, `PGHD_RUN_LOG_BASE_URL`, and
  `PGHD_RUN_LOG_TOKEN` before running `pnpm run test:e2e:pghd-note-draft`.

Exit checks:

```bash
npm test
npm run check:pghd:status
npm run check:pghd:release-readiness
npm run check:pghd:physio-handoff
npm run gate:pghd:release
npm run gate:pghd:physio-release
npm run gate:pghd:strict-staging
```

## Operating Rule

After Phase 1, treat the linked DB as applied through the PhysioApp owner
lineage, while broad `db push` from `strava-run-log` remains blocked. Any
deployment or schema change plan should say which one it is verifying:

- functional readiness: `npm run check:pghd:state-functional`
- owner-lineage and preflight surface readiness: `npm run check:pghd:status`
- release gate for the accepted apply path:
  `npm run check:pghd:release-readiness`
- combined Run-log + PhysioApp handoff readiness:
  `npm run check:pghd:physio-handoff`
- full PGHD release candidate gate with smoke cleanup check:
  `npm run gate:pghd:release`
- full PGHD release gate plus PhysioApp handoff surface:
  `npm run gate:pghd:physio-release`
- strict staging handoff proof with temporary org-client context and persisted
  state materialization: `npm run gate:pghd:strict-staging`
- smoke artifact cleanup check: `npm run check:pghd:smoke-cleanup`
- local migration-history reconciliation: inspect
  `npm run check:pghd:migration-history` `nextActions`, then fetch remote
  history before any focused repair
- guarded migration-history apply:
  `PGHD_MIGRATION_RECONCILE_APPLY=20260622145528 npm run apply:pghd:migration-reconciliation`

The combined handoff readiness command does not mutate Supabase migration
history. It checks this repo's release readiness, PhysioApp production/ops
readiness, and the configured Run-log import surface in PhysioApp:
authenticated proxy route, run-log client helper, server token allowlist,
encounter import panel, and fixture-backed E2E coverage.
