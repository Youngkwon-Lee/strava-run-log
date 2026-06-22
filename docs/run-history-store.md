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

The file is JSON Lines. Each line is one normalized run record.

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

This is an MVP persistence layer, not a production database.

- Vercel `/tmp` data can disappear across cold starts or deployments.
- Concurrent writes are simple read-modify-write operations, not transactional.
- There is no user-level access control inside the store file.
- There is no migration/versioning system yet.

For production, keep the `lib/run-store.js` API boundary and replace the file implementation with Postgres, Redis/KV, S3, or another durable backend.

## Next Adapter Shape

The next storage adapter should preserve these operations:

- `readStoredRuns(opts)`
- `upsertStoredRun(run, opts)`
- `filterStoredRuns(runs, opts)`
- `summarizeStoredRuns(runs)`

API handlers should not know whether the backing store is JSONL, SQL, object storage, or KV.
