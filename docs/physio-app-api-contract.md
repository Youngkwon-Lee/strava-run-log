# Physio App PGHD API Contract

## Purpose

This contract defines the server API surface that `physio_app` can consume before the run-log bridge is fully merged into the main app.

Current boundary:

- `run_log_runs`: provider-originated PGHD staging and normalized run history
- `pghd_connections`: provider account to physio app person mapping
- `activity_sessions`: promoted workflow/session records

All endpoints below are server-side/admin endpoints. Do not call them directly from a public browser with a service role key.

## Auth

Accepted request auth:

```http
Authorization: Bearer <RUN_LOG_ADMIN_TOKEN or LIVE_METRICS_TOKEN>
```

Also accepted:

```http
x-run-log-token: <token>
x-live-token: <token>
```

Recommended physio_app usage:

- Call these endpoints only from a server route/action.
- Store the shared token as a server-only env var.
- Never expose `SUPABASE_SERVICE_ROLE_KEY` or this admin token through `NEXT_PUBLIC_*`.

Common errors:

```json
{ "error": "unauthorized" }
```

```json
{
  "error": "invalid request",
  "details": ["subject_person_id must be a UUID"]
}
```

## Provider Mapping

### `GET /api/pghd/connections`

Lists provider account mappings.

Query:

- `person_id`: optional UUID
- `provider`: optional text. Accepts UI values such as `apple-health`; DB storage may return `apple_health`.
- `provider_user_id`: optional text
- `limit`: optional number, max 200

Example:

```http
GET /api/pghd/connections?person_id=<person_id>&provider=apple-health
Authorization: Bearer <token>
```

Response:

```json
{
  "ok": true,
  "connections": [
    {
      "id": "connection_uuid",
      "person_id": "person_uuid",
      "provider": "apple_health",
      "provider_user_id": "healthkit-user-id",
      "connection_status": "connected",
      "last_sync_at": null,
      "sync_frequency_hours": null,
      "metadata": {},
      "created_at": "2026-06-22T00:00:00Z",
      "updated_at": "2026-06-22T00:00:00Z"
    }
  ],
  "count": 1
}
```

### `POST /api/pghd/connections`

Creates or updates a provider mapping by `(person_id, provider)`.

Body:

```json
{
  "person_id": "person_uuid",
  "provider": "apple-health",
  "provider_user_id": "healthkit-user-id",
  "connection_status": "connected",
  "metadata": {
    "source": "physio_app"
  }
}
```

Accepted provider input:

- `apple-health`
- `health-connect`
- `google-fit`
- `fitbit`
- `garmin`
- `google-calendar`

Storage normalizes hyphenated provider names to the physio_app DB convention, for example `apple-health` to `apple_health`.

Accepted statuses:

- `pending`
- `connected`
- `disconnected`
- `error`
- `revoked`

`active` is accepted as legacy input and stored as `connected`.

## Client Weekly Summary

### `GET /api/run-log/weekly-summaries`

Returns aggregated weekly run summaries from `run_log_weekly_summaries`.

Query:

- `subject_person_id`: optional UUID
- `organization_id`: optional UUID
- `org_client_profile_id`: optional UUID
- `user_id`: optional text
- `source`: optional text, for example `apple-health`
- `after`: optional `YYYY-MM-DD`
- `before`: optional `YYYY-MM-DD`
- `limit`: optional number, max 260, default 52

Recommended physio_app client dashboard call:

```http
GET /api/run-log/weekly-summaries?subject_person_id=<person_id>&limit=12
Authorization: Bearer <token>
```

Response:

```json
{
  "ok": true,
  "source": "run-log-weekly-summaries",
  "summaries": [
    {
      "week_start": "2026-06-15",
      "subject_person_id": "person_uuid",
      "organization_id": null,
      "org_client_profile_id": null,
      "user_id": "healthkit-user-id",
      "source": "apple-health",
      "run_count": 3,
      "total_km": 18.2,
      "moving_time_sec": 6300,
      "moderate_minutes": 105,
      "average_pace_sec_per_km": 346,
      "average_heartrate": 148,
      "average_cadence": 172,
      "first_run_at": "2026-06-15T06:00:00Z",
      "last_run_at": "2026-06-20T06:00:00Z"
    }
  ],
  "count": 1
}
```

Render guidance:

- `total_km`: weekly distance
- `moving_time_sec` or `moderate_minutes`: weekly activity time
- `average_pace_sec_per_km`: trend pace
- `average_heartrate`: cardiovascular trend
- `run_count`: consistency

## Client Timeline

### `GET /api/run-log/timeline`

Returns recent provider runs with their `activity_sessions` link state.

At least one scoped client filter is required:

- `subject_person_id`
- `user_id`
- `pghd_connection_id`

Other query:

- `source`: optional text
- `after`: optional `YYYY-MM-DD`
- `before`: optional `YYYY-MM-DD`
- `limit`: optional number, max 100, default 30

Recommended physio_app call:

```http
GET /api/run-log/timeline?subject_person_id=<person_id>&limit=30
Authorization: Bearer <token>
```

Response:

```json
{
  "ok": true,
  "source": "run-log-timeline",
  "query": {
    "subjectPersonId": "person_uuid",
    "limit": 30
  },
  "timeline": [
    {
      "id": "apple-health:apple_health_...",
      "kind": "run",
      "source": "apple-health",
      "externalId": "apple_health_...",
      "name": "Apple Health Run",
      "startedAt": "2026-06-22T01:00:00Z",
      "subjectPersonId": "person_uuid",
      "userId": "healthkit-user-id",
      "providerUserId": "healthkit-user-id",
      "pghdConnectionId": "connection_uuid",
      "activitySessionId": "activity_session_uuid",
      "linkedAt": "2026-06-22T01:10:00Z",
      "promoted": true,
      "dataClassification": "PGHD",
      "metrics": {
        "distanceMeters": 5120,
        "distanceKm": 5.12,
        "movingTimeSec": 1910,
        "paceSecPerKm": 373,
        "pace": "6:13/km",
        "averageHeartrate": 148,
        "averageCadence": 172
      },
      "session": {
        "id": "activity_session_uuid",
        "activityType": "competition",
        "source": "apple_health",
        "status": "completed",
        "performedAt": "2026-06-22T01:00:00Z",
        "durationSeconds": 1910,
        "hasTimeseries": false,
        "notes": "Imported from client Apple Health run history"
      }
    }
  ],
  "count": 1
}
```

Render guidance:

- Use `promoted` to show `session linked` versus `run only`.
- Use `metrics.distanceKm`, `metrics.movingTimeSec`, `metrics.pace`, `metrics.averageHeartrate`.
- Use `session.activityType` and `session.status` when `promoted=true`.
- Treat `dataClassification=PGHD` as client-generated/provider-originated data, not clinician-entered data.

Privacy note:

- This endpoint intentionally does not return full `raw` provider payloads.
- It requires a scoped client filter to avoid accidental broad PGHD listing.

## Promote Run To Activity Session

### `POST /api/run-log/promote-to-activity-session`

Creates an `activity_sessions` row from a stored run and links it back to `run_log_runs.activity_session_id`.

Body:

```json
{
  "source": "apple-health",
  "external_id": "apple_health_...",
  "subject_person_id": "person_uuid",
  "organization_id": "organization_uuid",
  "org_client_profile_id": "org_client_profile_uuid",
  "activity_type": "competition",
  "notes": "Imported from Apple Health"
}
```

Required:

- `source`
- `external_id`

Optional:

- `subject_person_id`: can be omitted if the run resolves through `pghd_connections`
- `organization_id`
- `org_client_profile_id`
- `created_by`
- `notes`
- `activity_type`

Allowed `activity_type`:

- `home_exercise`
- `clinic_exercise`
- `gym_training`
- `competition`
- `assessment`
- `daily_walk`
- `telehealth`
- `other`

Response:

```json
{
  "ok": true,
  "existing": false,
  "activitySessionId": "activity_session_uuid",
  "run": {
    "source": "apple-health",
    "externalId": "apple_health_...",
    "subjectPersonId": "person_uuid"
  }
}
```

Idempotency:

- If the run already has `activity_session_id`, the endpoint returns `existing: true` and does not create a duplicate session.

## Recommended Physio App Flow

1. Client profile page loads.
2. Server gets `person_id` from physio_app route/context.
3. Server calls:
   - `GET /api/run-log/weekly-summaries?subject_person_id=<person_id>&limit=12`
   - `GET /api/run-log/timeline?subject_person_id=<person_id>&limit=30`
4. UI renders:
   - weekly distance/time/pace/HR trend
   - timeline cards
   - linked/unlinked status
5. If an unlinked run should become a workflow activity, server calls:
   - `POST /api/run-log/promote-to-activity-session`
6. UI refreshes timeline.

## Environment

For this bridge service:

```env
RUN_STORE_BACKEND=supabase
SUPABASE_URL=<moai_web Supabase URL>
SUPABASE_SERVICE_ROLE_KEY=<server-only service role key>
RUN_LOG_ADMIN_TOKEN=<shared server-only token>
```

For local smoke verification, the script can read:

```env
PGHD_SMOKE_ENV_FILE=/Users/youngkwon/projects/physio_app/.env.local
```

## Verification

Run:

```bash
npm test
npm run smoke:pghd
npm run smoke:pghd:db
```

Expected:

- API unit tests pass
- E2E smoke inserts an Apple Health run, promotes it, verifies timeline, then deletes smoke rows
- DB smoke verifies insert/view/link behavior inside a rolled-back transaction

## Integration Decision

Short term:

- physio_app calls this bridge API from server-side code.

Medium term:

- Move the timeline API shape into physio_app if both apps share deployment/runtime.

Long term:

- Keep provider ingest adapters independent, but make physio_app the primary owner of client PGHD timeline rendering.
