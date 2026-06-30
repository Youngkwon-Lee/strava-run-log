# PGHD Staging Manifest

Date: 2026-06-23

This manifest separates the PGHD PR scope from unrelated parallel work.

## Run-Log Repo

Working directory:

```bash
cd /Users/youngkwon/Desktop/strava-run-log
```

Stage the Run-log PGHD PR with:

```bash
git add \
  .gitignore \
  README.md \
  api/run-log/timeline.js \
  api/run-log/weekly-summaries.js \
  api/run-log/encounter-insights.js \
  api/run-log/encounter-note-drafts.js \
  api/run-log/preflight.js \
  api/run-log/state-snapshots.js \
  docs/pghd-data-management.md \
  docs/pghd-ontology-mapping.md \
  docs/pghd-table-boundary-audit.md \
  docs/physio-app-api-contract.md \
  docs/physio-app-integration.md \
  docs/product-direction.md \
  docs/run-history-store.md \
  docs/pghd-execution-roadmap.md \
  docs/pghd-improvement-plan.md \
  docs/pghd-pr-body-2026-06-23.md \
  docs/pghd-pr-evidence-2026-06-23.md \
  docs/pghd-pr-summary-2026-06-23.md \
  docs/pghd-release-decision-working-tree-2026-06-23.md \
  index.css \
  index.html \
  lib/bridge-contract.js \
  lib/run-store.js \
  lib/encounter-insights.js \
  lib/encounter-note-export.js \
  lib/http-query.js \
  lib/human-state.js \
  lib/pghd-empty-response.js \
  package.json \
  scripts/smoke_pghd_e2e.mjs \
  scripts/apply_pghd_migration_reconciliation.mjs \
  scripts/apply_pghd_state_migration.mjs \
  scripts/apply_pghd_state_sql_direct.mjs \
  scripts/check_pghd_migration_history.mjs \
  scripts/check_pghd_physio_handoff_readiness.mjs \
  scripts/check_pghd_release_readiness.mjs \
  scripts/check_pghd_smoke_cleanup.mjs \
  scripts/check_pghd_state_functional.mjs \
  scripts/check_pghd_state_schema.mjs \
  scripts/check_pghd_status.mjs \
  scripts/plan_pghd_migration_reconciliation.mjs \
  scripts/report_pghd_release_decision.mjs \
  scripts/run_pghd_release_decision.mjs \
  scripts/smoke_dashboard_viewport.mjs \
  scripts/smoke_pghd_state_db.mjs \
  scripts/smoke_pghd_state_materialization.mjs \
  supabase/migrations/20260622145528_add_activity_event_state_snapshots.sql \
  supabase/migrations/20260623033034_add_pghd_activity_events_layer.sql \
  test/api.test.js \
  test/run-store.test.js \
  test/apply-pghd-migration-reconciliation.test.js \
  test/apply-pghd-state-migration.test.js \
  test/apply-pghd-state-sql-direct.test.js \
  test/check-pghd-migration-history.test.js \
  test/check-pghd-release-readiness.test.js \
  test/check-pghd-state-functional.test.js \
  test/check-pghd-state-schema.test.js \
  test/check-pghd-status.test.js \
  test/dashboard-html.test.js \
  test/encounter-insights.test.js \
  test/encounter-note-export.test.js \
  test/http-query.test.js \
  test/human-state.test.js \
  test/plan-pghd-migration-reconciliation.test.js \
  test/report-pghd-release-decision.test.js \
  test/run-pghd-release-decision.test.js \
  test/state-smoke-scripts.test.js
```

## PhysioApp Repo

Working directory:

```bash
cd /Users/youngkwon/projects/physio_app
```

Stage only the PGHD handoff/owner-lineage files with:

```bash
git add \
  e2e/pghd-note-draft-handoff.verify.spec.ts \
  scripts/pghd-run-log-fixture.mjs \
  src/app/api/app/encounters/[encounterId]/pghd-note-draft/__tests__/route.test.ts \
  src/features/encounter-room/components/__tests__/pghd-note-draft-handoff-panel.test.tsx \
  src/features/encounter-room/components/encounter-room.tsx \
  src/features/encounter-room/components/pghd-note-draft-handoff-panel.tsx \
  src/features/encounter-room/server/__tests__/pghd-note-draft-handoff.test.ts \
  docs/db/PGHD_ACTIVITY_EVENTS_LAYER_2026-06-23.md \
  supabase/migrations/20260623051621_add_pghd_activity_events_layer.sql
```

Do not stage unrelated dirty files from parallel work.

## Post-Stage Checks

After staging, verify scope with:

```bash
git diff --cached --name-only
git diff --cached --check
```
