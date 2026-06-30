# Run History Store

## Purpose

The run history store is the shared persistence boundary for normalized provider activity events. It lets Strava and Apple Health data appear in the same dashboard, weekly report, future coaching context, and physio app state signals.

## Current Implementation

Module:

- `lib/run-store.js`

Default paths:

- Local: `.data/runs.jsonl`
- Vercel/serverless: blocked by default. Use `RUN_STORE_ALLOW_EPHEMERAL_FILE=1`
  only for temporary smoke/dev runs that intentionally write
  `/tmp/strava-run-log/runs.jsonl`.
- Override: `RUN_STORE_PATH=/absolute/path/to/runs.jsonl`
- Supabase/Postgres: `RUN_STORE_BACKEND=supabase`

The file is JSON Lines. Each line is one normalized run record.

For Supabase mode, records are written through two compatible layers:

- `public.pghd_activity_events`: generic PGHD activity-event staging for running, walking, cycling, rehab exercise, wearable summaries, and future non-running sources.
- `public.run_log_runs`: running-specific projection and compatibility layer used by existing dashboard, weekly summary, timeline, and state logic.

`run_log_runs.pghd_activity_event_id` links back to the generic event when the new layer is present. The adapter treats `pghd_activity_events` as best-effort so older databases that only have `run_log_runs` keep working.

The canonical compact run payload is kept in `raw`. Typed columns such as `source`, `external_id`, `activity_type`, `start_date`, `distance_meters`, and `moving_time_sec` are query/index helpers.

For PGHD storage policy, retention, raw-size limits, telemetry handling, and dashboard aggregate guidance, see [`pghd-data-management.md`](pghd-data-management.md).

## Writers

The store is upserted by:

- `POST /api/apple-health/ingest`
- `POST /api/strava/webhook` for activity create/update events
- `GET /api/strava/activities` after Strava activities are fetched and normalized
- `GET /api/strava/weekly-report` after recent Strava activities are fetched and normalized

Upsert key:

- `${source}:${externalId}`
- Falls back to start time only when an external id is missing

## Readers

Stored-only reads:

```bash
curl "https://<your-domain>/api/strava/activities?source=stored&days=90&limit=50"
curl "https://<your-domain>/api/strava/weekly-report?source=stored"
```

The dashboard and settings page also use stored records as a fallback when Strava is not connected or live Strava reads fail.

## Normalized Fields

Typical fields:

- `id`
- `externalId`
- `source`
- `provider`
- `userId`
- `name`
- `startDate`
- `startedAt`
- `endedAt`
- `activityType`
- `distanceMeters`
- `distanceKm`
- `movingTimeSec`
- `movingTime`
- `elapsedTimeSec`
- `elapsedTime`
- `paceSecPerKm`
- `pace`
- `totalElevationGainMeters`
- `averageHeartrate`
- `maxHeartrate`
- `averageCadence`
- `calories`
- `sourceRecordType`
- `deviceName`
- `coaching`
- `subjectPersonId`
- `organizationId`
- `orgClientProfileId`
- `activitySessionId`
- `pghdActivityEventId`
- `pghdConnectionId`
- `linkedAt`
- `dataClassification`
- `rawSizeBytes`
- `telemetryRef`
- `storedAt`
- `updatedAt`

Source-specific fields may also be present.

## Derived State

`pghd_activity_events` and `run_log_runs` store source events/projections, not calculated state. Derived values such as training load, adherence, fatigue, recovery, and injury risk should be stored separately in:

- `public.human_state_snapshots`
- `public.human_state_snapshot_inputs`

Read them through:

```bash
curl "https://<your-domain>/api/run-log/state-snapshots?subject_person_id=<person_id>&limit=12"
```

Calculate ad-hoc weekly state signals without persisted rows:

```bash
curl "https://<your-domain>/api/run-log/state-snapshots?subject_person_id=<person_id>&derive=weekly&limit=12"
```

Add `source=apple-health` or another provider id to limit the returned state rows to one upstream PGHD provider. Without that filter, weekly derivation returns separate provider-specific state rows when multiple sources exist for the same person and week.

Materialize weekly state signals after the migration is applied:

```bash
curl -X POST "https://<your-domain>/api/run-log/state-snapshots" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"subject_person_id":"<person_id>","derive":"weekly","limit":12}'
```

`human_state_snapshot_inputs` can link to `run_log_runs` for running projections and to `pghd_activity_events` for the generic event provenance. This keeps the source event, workflow activity, atomic observation, and calculated state boundaries separate.

## Limitations

The file backend is an MVP persistence layer, not a production database.

- Vercel file storage is blocked by default because `/tmp` data can disappear
  across cold starts or deployments.
- Concurrent writes are simple read-modify-write operations, not transactional.
- There is no user-level access control inside the store file.
- There is no migration/versioning system yet.

For production, set `RUN_STORE_BACKEND=supabase` or keep the `lib/run-store.js` API boundary and replace the file implementation with another durable backend. If a Vercel smoke/dev run intentionally needs the old ephemeral behavior, set both `RUN_STORE_BACKEND=file` and `RUN_STORE_ALLOW_EPHEMERAL_FILE=1`.

## Supabase Setup

Apply:

```bash
supabase link --workdir /Users/youngkwon/Desktop/strava-run-log --project-ref <project-ref>
supabase db push --workdir /Users/youngkwon/Desktop/strava-run-log
```

or paste `supabase/migrations/20260622014705_create_run_store.sql` into the Supabase SQL editor.

Use `--workdir` from this repo because other Supabase projects may be linked elsewhere on the same machine.

If the target Supabase project already has a separate migration history, `db push` can fail with remote migration versions not found locally. In that case, apply only this table with:

```bash
supabase db query --workdir /Users/youngkwon/Desktop/strava-run-log --linked --file supabase/migrations/20260622014705_create_run_store.sql
```

Required server-side environment variables:

```env
RUN_STORE_BACKEND=supabase
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<server-only-service-role-key>
RUN_STORE_SUPABASE_TABLE=run_log_runs
PGHD_ACTIVITY_EVENTS_TABLE=pghd_activity_events
```

Security notes:

- `public.run_log_runs` has RLS enabled.
- The app uses the service role key from server-side API routes only.
- Do not expose `SUPABASE_SERVICE_ROLE_KEY` in client-side JavaScript or `NEXT_PUBLIC_*` variables.
- No anon/authenticated policies are created yet, so browser clients cannot read/write this table directly.

Free plan notes:

- Supabase Free is suitable for this project as a personal MVP if only normalized run summaries are stored.
- Avoid storing dense GPS streams, route points, screenshots, or raw wearable telemetry in `raw`.
- If the project grows to multiple users or large route history, move high-volume telemetry to object storage or a separate compressed table with retention.
- `RUN_STORE_MAX_RAW_BYTES` defaults to `65536`; payloads above that are rejected before upsert.
- `run_log_weekly_summaries` is the preferred query surface for weekly dashboard trends.

## Smoke Test

After applying the table and setting env vars, verify the adapter without Vercel:

```bash
RUN_STORE_BACKEND=supabase \
SUPABASE_URL=https://<project-ref>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<server-only-service-role-key> \
RUN_STORE_SUPABASE_TABLE=run_log_runs \
node scripts/smoke_supabase_run_store.mjs
```

The script upserts one `source='smoke-test'` row, reads it back through `lib/run-store.js`, and prints a compact JSON result. Delete smoke rows after verification:

```sql
delete from public.run_log_runs where source = 'smoke-test';
```

## Next Adapter Shape

The next storage adapter should preserve these operations:

- `readStoredRuns(opts)`
- `upsertStoredRun(run, opts)`
- `filterStoredRuns(runs, opts)`
- `summarizeStoredRuns(runs)`

API handlers should not know whether the backing store is JSONL, SQL, object storage, or KV.
