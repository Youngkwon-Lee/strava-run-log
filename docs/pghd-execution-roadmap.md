# PGHD Execution Roadmap

Last checked: 2026-06-23

This roadmap turns the PGHD improvement plan into an operator-ready sequence.
The product direction is fixed: `strava-run-log` is a lightweight PGHD
intelligence layer that turns running and wearable data into:

```text
Provider activity
-> Activity Event
-> Human State
-> Encounter Insight
-> PhysioApp draft handoff
```

## Non-Negotiable Constraints

- Do not run broad `supabase db push` from this repo against the linked
  project.
- Treat the linked database schema as owned by the PhysioApp migration lineage.
- Use the PhysioApp owner-lineage bridge path for schema apply proof.
- Keep PGHD smoke data temporary: cleanup proof is part of the release gate.
- Keep generated note content in draft/review flow. Do not write final clinical
  notes directly from run-log.

## Milestone 1: Lock The Current Release Candidate

Goal: prove the current PGHD bridge is stable before adding new product surface.

Required evidence:

```bash
npm test
npm run gate:pghd:release
npm run gate:pghd:physio-release
npm run gate:pghd:strict-staging
```

Exit criteria:

- Unit and API coverage are green.
- Dashboard viewport smoke proves the PGHD review brief renders first.
- PGHD E2E smoke proves ingest, weekly summary, preflight, promotion, and
  cleanup.
- Strict staging proves a temporary org-client subject can materialize persisted
  Human State without leaving smoke artifacts.
- PhysioApp handoff surface remains present and compatible.

Stop policy:

- If `check:pghd:status` reports `dbPushBlocked: true`, do not try to unblock
  it with `supabase db push` from this repo. Use the owner-lineage result as the
  accepted apply path.

## Milestone 2: Make The Dashboard A PGHD Review Surface

Goal: make the first screen answer the professional/user question: "what changed
and what should be reviewed?"

Implement only changes that strengthen these first-screen priorities:

- current Human State summary
- highest-priority Encounter Insight
- confidence and insufficient-data reason
- source traceability to the activity events that produced the state
- operator preflight status when the subject is not handoff-ready

Avoid adding:

- more raw activity list prominence
- generic social fitness feed behavior
- clinical diagnosis language
- final-note automation without professional review

Required evidence:

```bash
npm test
npm run smoke:dashboard:viewport
```

Optional live evidence:

```bash
npm run smoke:pghd
```

## Milestone 3: Tighten PhysioApp Encounter Handoff

Goal: make the handoff feel native in the active encounter room.

Priority work:

1. Add richer encounter-context probes once the bridge can authenticate against
   a specific organization/provider session boundary.
2. Keep the import path server-side so the Run-log token never reaches the
   browser.
3. Preserve `draftExport.repositoryParams` as the narrow PhysioApp upsert
   contract.
4. Preserve professional review actions: `accepted` when unchanged, `modified`
   when edited.
5. Keep provenance in `ai_draft_snapshot` and
   `discipline_sections.pghd_note_draft`; do not overload PhysioApp
   `encounter_notes.data`.

Required evidence:

```bash
npm run check:pghd:physio-handoff
npm run gate:pghd:physio-release
```

Staging E2E evidence when a real Run-log deployment is available:

```bash
E2E_PGHD_RUN_LOG_FIXTURE=0 \
PGHD_RUN_LOG_BASE_URL=<staging-run-log-url> \
PGHD_RUN_LOG_TOKEN=<server-token> \
pnpm run test:e2e:pghd-note-draft
```

Run that command from the PhysioApp checkout, not from this repo.

## Milestone 4: Improve Data Quality Semantics

Goal: make every state and insight explain how much trust it deserves.

Each Human State or Encounter Insight should expose:

- source provider
- source activity count
- recency window
- confidence
- data quality flags
- insufficient-data reasons
- week-over-week direction when available

Required evidence:

```bash
npm test
npm run smoke:pghd:state
```

Live-readiness evidence:

```bash
npm run smoke:pghd:strict-full
npm run check:pghd:smoke-cleanup
```

## Milestone 5: Production Readiness Decision

Goal: decide whether a candidate is ready to expose as a PGHD bridge for real
PhysioApp usage.

Run the full gate set:

```bash
npm run gate:pghd:release
npm run gate:pghd:physio-release
npm run gate:pghd:strict-staging
npm run check:pghd:status
```

Then capture the current decision record:

```bash
PGHD_RELEASE_CANDIDATE=<candidate-name> \
PGHD_RELEASE_ENVIRONMENT=<local|staging|production> \
PGHD_RELEASE_COMMANDS_RUN=$'npm run gate:pghd:release\nnpm run gate:pghd:physio-release\nnpm run gate:pghd:strict-staging\nnpm run check:pghd:status' \
npm run report:pghd:release-decision
```

This report does not replace the gate output. It runs the existing release
readiness checks, then packages the current readiness/apply-path state into the
decision-log fields below. If `PGHD_RELEASE_COMMANDS_RUN` omits any required
gate, the report keeps `ok` tied to release readiness but records the missing
gate evidence under `evidence.missingGateEvidence`.

Do not run multiple Supabase CLI readiness commands in parallel against the
same linked project. They share the linked CLI context and can hit transient
migration-list timeouts; use `PGHD_MIGRATION_LIST_TIMEOUT_MS` if the linked
project is slow.

To run the required commands sequentially and generate the decision record in
one pass, use:

```bash
PGHD_RELEASE_CANDIDATE=<candidate-name> \
PGHD_RELEASE_ENVIRONMENT=<local|staging|production> \
npm run gate:pghd:decision
```

This command stops at the first failed gate. The JSON output still records the
commands that completed and the missing gate evidence. It also writes the same
record to `output/pghd-release-decision/latest.json`; override that path with
`PGHD_RELEASE_DECISION_OUTPUT`.

Approve only when:

- `preflightSurfaceOk: true`
- `functionalOk: true`
- `migrationHistoryOk: true`
- `ownerBridgeApplied: true`
- `recommendedApplyPath: "physio-app-owner-lineage"` or a reviewed successor
  path
- smoke cleanup reports zero bootstrap connections, smoke runs, and active
  smoke persons

Expected residual condition:

- `localMigrationHistoryOk: false`
- `dbPushBlocked: true`
- `dbPushAllowed: false`

That residual condition is acceptable for this repo. It is a guardrail that
keeps schema ownership in PhysioApp.

## Command Matrix

| Situation | Command |
| --- | --- |
| Fast local confidence | `npm test` |
| Dashboard first-screen check | `npm run smoke:dashboard:viewport` |
| Live PGHD smoke with existing subject | `npm run smoke:pghd` |
| Strict org-client subject proof | `npm run smoke:pghd:strict-org-client` |
| Strict org-client plus persisted state proof | `npm run smoke:pghd:strict-full` |
| Smoke artifact audit | `npm run check:pghd:smoke-cleanup` |
| Owner-lineage readiness status | `npm run check:pghd:status` |
| Accepted apply-path release check | `npm run check:pghd:release-readiness` |
| Release decision record | `npm run report:pghd:release-decision` |
| Sequential release decision gate | `npm run gate:pghd:decision` |
| Run-log release candidate gate | `npm run gate:pghd:release` |
| Run-log plus PhysioApp handoff gate | `npm run gate:pghd:physio-release` |
| Strict staging handoff proof | `npm run gate:pghd:strict-staging` |

## Decision Log Template

Use this shape when recording a release or staging decision:

```text
Candidate:
Date:
Environment:
Apply path:
Commands run:
Result:
Residual risks:
Next action:
```

Current tracked decision:
[`pghd-release-decision-working-tree-2026-06-23.md`](pghd-release-decision-working-tree-2026-06-23.md)
