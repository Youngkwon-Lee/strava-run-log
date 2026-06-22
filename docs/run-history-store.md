# Run History Store

## Purpose

The run history store is the shared persistence boundary for normalized running records. It lets Strava and Apple Health data appear in the same dashboard, weekly report, and future coaching context.

## Current Implementation

Module:

- `lib/run-store.js`

Default paths:

- Local: `.data/runs.jsonl`
- Vercel/serverless: `/tmp/strava-run-log/runs.jsonl`
- Override: `RUN_STORE_PATH=/absolute/path/to/runs.jsonl`
- Supabase/Postgres: `RUN_STORE_BACKEND=supabase`

The file is JSON Lines. Each line is one normalized run record.

For Supabase mode, records are stored in `public.runs` and the canonical run payload is kept in the `raw` JSONB column. Typed columns such as `source`, `external_id`, `start_date`, `distance_meters`, and `moving_time_sec` are query/index helpers.

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
- `deviceName`
- `coaching`
- `storedAt`
- `updatedAt`

Source-specific fields may also be present.

## Limitations

The file backend is an MVP persistence layer, not a production database.

- Vercel `/tmp` data can disappear across cold starts or deployments.
- Concurrent writes are simple read-modify-write operations, not transactional.
- There is no user-level access control inside the store file.
- There is no migration/versioning system yet.

For production, set `RUN_STORE_BACKEND=supabase` or keep the `lib/run-store.js` API boundary and replace the file implementation with another durable backend.

## Supabase Setup

Apply:

```bash
supabase db push
```

or paste `supabase/migrations/20260622014705_create_run_store.sql` into the Supabase SQL editor.

Required server-side environment variables:

```env
RUN_STORE_BACKEND=supabase
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<server-only-service-role-key>
RUN_STORE_SUPABASE_TABLE=runs
```

Security notes:

- `public.runs` has RLS enabled.
- The app uses the service role key from server-side API routes only.
- Do not expose `SUPABASE_SERVICE_ROLE_KEY` in client-side JavaScript or `NEXT_PUBLIC_*` variables.
- No anon/authenticated policies are created yet, so browser clients cannot read/write this table directly.

Free plan notes:

- Supabase Free is suitable for this project as a personal MVP if only normalized run summaries are stored.
- Avoid storing dense GPS streams, route points, screenshots, or raw wearable telemetry in `raw`.
- If the project grows to multiple users or large route history, move high-volume telemetry to object storage or a separate compressed table with retention.

## Next Adapter Shape

The next storage adapter should preserve these operations:

- `readStoredRuns(opts)`
- `upsertStoredRun(run, opts)`
- `filterStoredRuns(runs, opts)`
- `summarizeStoredRuns(runs)`

API handlers should not know whether the backing store is JSONL, SQL, object storage, or KV.
