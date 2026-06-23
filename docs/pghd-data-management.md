# PGHD Data Management Policy

## Goal

The system should support client dashboards and professional review without turning Postgres into a raw telemetry lake.

Use the database for identity, queryable summaries, workflow links, and dashboard aggregates. Use object storage or a dedicated compressed telemetry table for high-volume streams only when the product needs them.

## Storage Tiers

### 1. Provider ingest payload

Examples:
- Strava activity response
- Apple Health workout summary
- GPX/TCX file import
- Future Garmin activity payload

- Normalize into `pghd_activity_events`, then project running records into `run_log_runs`.
- Keep compact provider fields in `pghd_activity_events.raw` and `run_log_runs.raw`.
- Use `(source, external_id)` as the idempotency key.
- Do not store screenshots, large files, dense GPS arrays, or per-second watch streams in `raw`.

Current enforcement:
- `RUN_STORE_MAX_RAW_BYTES`, default `65536`.
- `run_log_runs.raw_size_bytes`.
- `pghd_activity_events.data_classification` and `run_log_runs.data_classification`, default `PGHD`.
- Dense `streams` and route point arrays over 100 points are pruned from `raw` and represented by `telemetryRef`.

### 2. Generic activity event

Stored in `pghd_activity_events`:
- `source`
- `external_id`
- `source_record_type`
- `activity_type`
- `subject_person_id`
- `organization_id`
- `org_client_profile_id`
- `pghd_connection_id`
- `started_at`
- `ended_at`
- `duration_seconds`
- `metrics`
- `raw`

This is the generic PGHD staging layer for running and future activity types.

### 3. Normalized run summary

Stored in typed columns on `run_log_runs`:
- `source`
- `external_id`
- `user_id`
- `name`
- `start_date`
- `distance_meters`
- `moving_time_sec`
- `pace_sec_per_km`
- `average_heartrate`
- `average_cadence`
- physio link fields such as `subject_person_id`, `organization_id`, `activity_session_id`
- `pghd_activity_event_id` link to the generic source event

This is the main dashboard query layer.

### 4. Workflow-attached activity

Stored in `activity_sessions` after promotion.

Promotion means:
- A provider run has been mapped to `subject_person_id`.
- A professional/client workflow context exists.
- The run can appear in rehab, return-to-activity, or client timeline views.

### 5. High-volume telemetry

Examples:
- full GPS route
- per-second heart rate
- cadence stream
- power/ground-contact/IMU streams

Policy:
- Do not put this in `pghd_activity_events.raw` or `run_log_runs.raw`.
- Store externally if needed:
  - Supabase Storage JSON/JSONL gzip
  - compressed telemetry table
  - object storage partitioned by organization/person/date/source
- Keep only `telemetry_ref` and summary statistics in Postgres.

### 6. Dashboard aggregates

The migration `20260622040100_add_pghd_storage_policy.sql` adds:
- `run_log_weekly_summaries`

Use this view for trend/dashboard reads instead of scanning raw payloads.

## Retention

Recommended MVP policy:
- Keep normalized summaries indefinitely while the user/client account is active.
- Keep compact raw provider payloads for 12-24 months unless needed for audit/debug.
- Keep dense telemetry only for linked clients, active programs, or explicitly saved workouts.
- Delete or archive raw telemetry after the clinical/program review window.

Column:
- `raw_retention_until` marks when `raw` may be pruned while typed summary columns remain.

## Display Rules

Client dashboard:
- timeline of activities
- weekly distance/time/moderate minutes
- pace and heart-rate trends
- status badges for source and linked/unlinked state

Professional dashboard:
- linked `activity_sessions`
- compliance and consistency
- sudden load changes
- return-to-activity criteria context
- drill-down to provider raw only when necessary

## Practical Answer

No, do not store all big data in the main DB.

Store:
- summary rows in Postgres
- workflow links in Postgres
- aggregate views/materialized summaries for dashboards
- raw telemetry externally and only when it earns its storage cost
