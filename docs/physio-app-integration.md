# Physio App Integration

## Current Position

`strava-run-log` now stores normalized provider running records in `public.run_log_runs` inside the `moai_web` Supabase project.

`moai_web` already has `public.activity_sessions`, which is the better long-term integration point for physio app workflows. However, `activity_sessions` is clinical/workflow oriented and expects fields such as `subject_person_id`, `organization_id`, `episode_id`, `encounter_id`, and `care_plan_id`.

For now, `run_log_runs` should remain the raw/normalized provider history table. Selected rows can later be linked or promoted into `activity_sessions`.

## Existing Relevant Tables

- `public.activity_sessions`
  - General activity/session record for app workflows.
  - Has `subject_person_id`, `organization_id`, `activity_type`, `source`, `performed_at`, `duration_seconds`, `metrics`, `exercise_log`, `has_timeseries`, and `timeseries_ref`.
- `public.org_client_profile`
  - Organization-specific client/patient profile.
- `public.pilot_patients`
  - Pilot patient/person records.
- `public.return_to_activity_criteria`
  - Criteria reference data for return-to-activity guidance.

## Recommended Boundary

Use two layers:

1. `public.run_log_runs`
   - Provider-originated running history.
   - Idempotent upsert by `(source, external_id)`.
   - Stores normalized app payload in `raw`.
   - Safe to import/re-import from Strava or Apple Health.

2. `public.activity_sessions`
   - Physio app workflow/session record.
   - Created only when a run is intentionally attached to a person/care context.
   - Can reference the provider run through metadata or a future FK.

## Future Columns

When the integration needs identity mapping, add nullable columns to `run_log_runs`:

```sql
alter table public.run_log_runs
  add column if not exists subject_person_id uuid,
  add column if not exists activity_session_id uuid;
```

Optional later fields:

- `organization_id uuid`
- `org_client_profile_id uuid`
- `source_account_id uuid`
- `linked_at timestamptz`

Keep them nullable so standalone personal running logs continue to work.

## Promotion Flow

Suggested flow for turning a stored run into a physio app activity:

1. Read a `run_log_runs` row.
2. Resolve the app person:
   - `user_id` or provider account -> `subject_person_id`
3. Insert `activity_sessions`:
   - `subject_person_id`
   - `activity_type = 'run'`
   - `source = run_log_runs.source`
   - `performed_at = run_log_runs.start_date`
   - `duration_seconds = run_log_runs.moving_time_sec`
   - `metrics = jsonb_build_object(...)`
   - `exercise_log = run_log_runs.raw`
   - `has_timeseries = false` unless route/stream storage is added
4. Store the resulting `activity_sessions.id` back on `run_log_runs.activity_session_id`.

## Data Volume Guidance

Keep `run_log_runs.raw` compact:

- Store summaries, splits, coaching, and provider ids.
- Avoid dense GPS points and per-second telemetry in `raw`.
- Use object storage or a separate compressed telemetry table if route streams become necessary.

This keeps the Supabase Free database viable for MVP usage.
