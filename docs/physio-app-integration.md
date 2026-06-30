# Physio App Integration

## Current Position

`strava-run-log` stores normalized provider activity records in a PGHD staging path inside the `moai_web` Supabase project.

`moai_web` already has `public.activity_sessions`, which is the better long-term integration point for physio app workflows. However, `activity_sessions` is clinical/workflow oriented and expects fields such as `subject_person_id`, `organization_id`, `activity_type`, `source`, `performed_at`, and `duration_seconds`.

For now, `pghd_activity_events` is the generic raw/normalized provider event layer and `run_log_runs` remains the running-specific projection/compatibility table. Selected rows can later be linked or promoted into `activity_sessions`.

In PGHD terms, `pghd_activity_events` is the provider-originated PGHD staging layer, `run_log_runs` is the run projection, and `activity_sessions` is the professional workflow layer after person/client mapping. See [`pghd-ontology-mapping.md`](pghd-ontology-mapping.md).

Derived human state values such as training load, adherence, and fatigue live outside both tables in `public.human_state_snapshots`, with source traceability through `public.human_state_snapshot_inputs`.

The API contract that physio_app should consume is fixed in [`physio-app-api-contract.md`](physio-app-api-contract.md).

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

Use three storage/interpretation layers:

1. `public.pghd_activity_events`
   - Provider-originated generic PGHD activity events.
   - Idempotent upsert by `(source, external_id)`.
   - Stores normalized app payload in `raw` and compact event metrics in `metrics`.
   - Safe to import/re-import from Strava, Apple Health, Apple Watch, Garmin, GPX/TCX, and future non-running sources.

2. `public.run_log_runs`
   - Running-specific projection and compatibility table.
   - Links to `pghd_activity_events.id` through `pghd_activity_event_id` when the generic layer is applied.
   - Stores query helpers such as `subject_person_id`, `activity_type`, `ended_at`, `max_heartrate`, `calories`, `source_record_type`, and `imported_at`.

3. `public.activity_sessions`
   - Physio app workflow/session record.
   - Created only when a run is intentionally attached to a person/care context.
   - Can reference the provider run through metadata or a future FK.

4. `public.human_state_snapshots`
   - Derived state signals calculated from provider activity events or aggregate PGHD.
   - Stores calculation source separately from upstream provider source.
   - Should be used for training load, adherence, fatigue, recovery, fitness, and injury risk values.

## Implemented Run Link Columns

Identity and workflow-linking columns on `run_log_runs`:

```sql
subject_person_id uuid
organization_id uuid
org_client_profile_id uuid
activity_session_id uuid
pghd_activity_event_id uuid
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
   - `activity_type = request.activity_type` or `other`
   - `source = mapped provider source`, for example `apple_health`, `app_guided`, or `manual`
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

Related read endpoints:

- `GET /api/run-log/weekly-summaries`
- `GET /api/run-log/timeline`
- `GET /api/run-log/state-snapshots`
- `POST /api/run-log/state-snapshots`
- `GET /api/run-log/encounter-insights`
- `GET /api/run-log/preflight`
- `GET/POST /api/pghd/connections`

See [`physio-app-api-contract.md`](physio-app-api-contract.md) for exact auth, query, response, and error shapes.

## Data Volume Guidance

Keep `pghd_activity_events.raw` and `run_log_runs.raw` compact:

- Store summaries, splits, coaching, and provider ids.
- Avoid dense GPS points and per-second telemetry in `raw`.
- Use object storage or a separate compressed telemetry table if route streams become necessary.

This keeps the Supabase Free database viable for MVP usage.
