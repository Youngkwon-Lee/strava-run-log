# PGHD Table Boundary Audit

## Current Supabase Tables

Checked on the linked `moai_web` Supabase project.

Relevant tables/views:

| Table/View | Current role | Row count at audit | Keep? | Notes |
| --- | --- | ---: | --- | --- |
| `run_log_runs` | Provider workout/session summary staging | 0 | Yes | Source-normalized run records from Strava, Apple Health, Garmin, GPX/TCX. |
| `run_log_weekly_summaries` | Weekly dashboard aggregate view | n/a | Yes | Query helper over `run_log_runs`; not a data duplicate. |
| `pghd_connections` | Person-to-provider connection state | 2 | Yes | Connection/account metadata and tokens. Should link future provider accounts. |
| `pghd_observations` | Atomic PGHD/FHIR-like observations | 0 | Yes | Heart rate, steps, calories, exercise minutes, device readings. Not a workout-session table. |
| `pghd_code_mappings` | PGHD ontology/code mapping | 0 | Yes | LOINC/Open mHealth/local code mapping reference. |
| `activity_sessions` | Professional/client workflow activity | 132 | Yes | The physio app timeline/workflow table after person/client mapping. |

## Decision

There is no active row-level data duplication right now.

The potential schema overlap is real, so use this boundary:

1. `pghd_connections`
   - Stores provider connection metadata.
   - Examples: Apple Health bridge profile, Garmin account, future Strava provider user mapping.
   - Does not store workout summaries.

2. `run_log_runs`
   - Stores one row per workout/run session from a provider.
   - This is PGHD staging for session-level activity data.
   - Idempotent by `(source, external_id)`.
   - Keeps compact raw payload and queryable summary columns.

3. `pghd_observations`
   - Stores atomic observations when needed.
   - Examples: resting heart rate, daily step count, HRV, weight, sleep duration, weekly exercise minutes, single heart-rate measurement.
   - A run may produce derived observations later, but the full workout should not be duplicated here as another session record.

4. `activity_sessions`
   - Stores professional workflow records.
   - Create only after a `run_log_runs` row is attached to `subject_person_id` and workflow context.
   - This is what professional/client dashboards should treat as the clinical/rehab activity surface.

## Mapping Rule

Do not write the same run into all tables by default.

Recommended flow:

```text
provider connection -> pghd_connections
provider workout -> run_log_runs
linked client workflow -> activity_sessions
selected atomic metrics -> pghd_observations only when needed
weekly trend UI -> run_log_weekly_summaries
```

Current implementation:

- `lib/pghd-connections.js` resolves `provider + provider_user_id` to `pghd_connections.person_id`.
- `lib/run-store.js` attempts this mapping before Supabase upsert and writes `subject_person_id` plus `pghd_connection_id` when a unique connection exists.
- `POST /api/run-log/promote-to-activity-session` can omit `subject_person_id` when the stored run can be resolved through `pghd_connections`.
- If the mapping is missing or ambiguous, promotion still requires explicit `subject_person_id`.

## Examples

Apple Watch morning run:

- `pghd_connections`: Apple Health bridge connection for the person.
- `run_log_runs`: one row for the workout summary.
- `activity_sessions`: one row only after the professional/client mapping exists.
- `pghd_observations`: optional derived rows, such as average heart rate or weekly moderate minutes, only if another clinical feature needs atomic Observation-style data.

Daily resting heart rate:

- `pghd_connections`: source account.
- `pghd_observations`: one atomic heart-rate observation.
- `run_log_runs`: no row.
- `activity_sessions`: no row unless explicitly reviewed/attached to a workflow.

## RLS Advisor Notes

Supabase advisor warnings seen during this audit were mostly existing `moai_web` policies, not new `run_log_runs` policies.

Common warning:

- `auth_rls_initplan`

Meaning:

- A policy calls `auth.uid()` or a helper function directly in the row predicate.
- Postgres may re-evaluate it for each row.
- At scale, rewrite `auth.uid()` as `(select auth.uid())` and consider caching stable helper results in subqueries.

Examples from existing project tables:

- `ff_assess_sessions.ff_assess_own`
- `ff_exercise_sessions.ff_exercise_own`
- `updrs_results.*`
- `clinical_reasoning_usage_events.*`
- `account_consent.account_consent_select_own`

Current `strava-run-log` action taken:

- `run_log_weekly_summaries` uses `security_invoker = true`.
- `set_run_log_runs_updated_at()` now has fixed `search_path = public, pg_temp`.
- No remaining advisor warning was observed for `set_run_log_runs_updated_at`.

## Next Recommendation

Before wiring the client app:

1. Use `pghd_connections` for provider account/client mapping.
2. Keep `run_log_runs` as the workout staging table.
3. Add an explicit promotion/export step from `run_log_runs` to `pghd_observations` only for selected atomic metrics.
4. Do not migrate `run_log_runs` into `pghd_observations`; they represent different granularity.
