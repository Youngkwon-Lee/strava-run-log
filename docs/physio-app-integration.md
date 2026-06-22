# Physio App Integration

## Current Position

`strava-run-log` now stores normalized provider running records in `public.run_log_runs` inside the `moai_web` Supabase project.

`moai_web` already has `public.activity_sessions`, which is the better long-term integration point for physio app workflows. However, `activity_sessions` is clinical/workflow oriented and expects fields such as `subject_person_id`, `organization_id`, `episode_id`, `encounter_id`, and `care_plan_id`.

For now, `run_log_runs` should remain the raw/normalized provider history table. Selected rows can later be linked or promoted into `activity_sessions`.

In PGHD terms, `run_log_runs` is the provider-originated PGHD staging layer and `activity_sessions` is the professional workflow layer after person/client mapping. See [`pghd-ontology-mapping.md`](pghd-ontology-mapping.md).

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

Identity mapping columns on `run_log_runs`:

```sql
subject_person_id uuid
organization_id uuid
org_client_profile_id uuid
activity_session_id uuid
linked_at timestamptz
```

Optional later fields:

- `source_account_id uuid`

Keep them nullable so standalone personal running logs continue to work.

## Promotion Flow

Suggested flow for turning a stored run into a physio app activity:

1. Read a `run_log_runs` row.
2. Resolve the app person:
   - `user_id` or provider account -> `subject_person_id`
   - current implementation first tries `pghd_connections(provider, provider_user_id)`
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

Implemented endpoint:

```http
POST /api/run-log/promote-to-activity-session
Authorization: Bearer <RUN_LOG_ADMIN_TOKEN or LIVE_METRICS_TOKEN>
Content-Type: application/json
```

Body:

```json
{
  "source": "apple-health",
  "external_id": "apple_health_...",
  "subject_person_id": "11111111-1111-4111-8111-111111111111",
  "organization_id": "22222222-2222-4222-8222-222222222222",
  "org_client_profile_id": "33333333-3333-4333-8333-333333333333",
  "notes": "Imported from client Apple Health run history"
}
```

Only `source` and `external_id` are always required. `subject_person_id` is required only when the run cannot be resolved through `pghd_connections`. The endpoint is idempotent for already-linked runs: if `activity_session_id` exists, it returns the existing id instead of creating a duplicate session.

## Data Volume Guidance

Keep `run_log_runs.raw` compact:

- Store summaries, splits, coaching, and provider ids.
- Avoid dense GPS points and per-second telemetry in `raw`.
- Use object storage or a separate compressed telemetry table if route streams become necessary.

This keeps the Supabase Free database viable for MVP usage.
