# Physio App PGHD API Contract

## Purpose

This contract defines the server API surface that `physio_app` can consume before the run-log bridge is fully merged into the main app.

Current boundary:

- `pghd_activity_events`: provider-originated generic PGHD activity event staging
- `run_log_runs`: running-specific projection and normalized run history
- `pghd_connections`: provider account to physio app person mapping
- `activity_sessions`: promoted workflow/session records
- `human_state_snapshots`: derived state values calculated from activity events and related PGHD

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

## PGHD Preflight

### `GET /api/run-log/preflight`

Returns an operator-facing readiness summary for one client/source before or
alongside the heavier PGHD dashboard calls. It does not mutate data.

Query:

- `subject_person_id`: required UUID
- `source`: optional provider filter, for example `apple-health`
- `limit`: optional number, max 20, default 5

Example:

```http
GET /api/run-log/preflight?subject_person_id=<person_id>&source=apple-health
Authorization: Bearer <token>
```

Response:

```json
{
  "ok": true,
  "source": "run-log-pghd-preflight",
  "query": {
    "subjectPersonId": "person_uuid",
    "source": "apple-health",
    "limit": 5
  },
  "summary": {
    "status": "warning",
    "ok": true,
    "total": 5,
    "warningCount": 1,
    "errorCount": 0
  },
  "checks": [
    {
      "name": "physio_person_context",
      "status": "ok",
      "message": "PhysioApp person and org client context exist for this subject.",
      "count": 1
    },
    {
      "name": "connection_mapping",
      "status": "ok",
      "message": "PGHD connection mapping exists for this client/source.",
      "count": 1
    },
    {
      "name": "state_materialization",
      "status": "warning",
      "message": "No persisted Human State snapshots were found.",
      "count": 0,
      "operatorHints": [
        "Use derive=weekly for preview or POST /api/run-log/state-snapshots to materialize rows."
      ]
    }
  ],
  "nextActions": [
    "Use derive=weekly for preview or POST /api/run-log/state-snapshots to materialize rows."
  ]
}
```

Checks:

- `physio_person_context`: reads PhysioApp `persons` and `org_clients` for the
  requested `subject_person_id`. Missing rows are warnings so standalone
  run-log deployments do not hard-fail.
- `connection_mapping`: reads `pghd_connections` for the person/source.
- `activity_ingest`: reads recent `run_log_runs` rows.
- `weekly_summary`: reads `run_log_weekly_summaries`.
- `state_materialization`: reads persisted `human_state_snapshots` and returns a
  warning, not a hard failure, if the state tables are not migrated yet.

Render guidance:

- Use `summary.status` as the overall badge.
- Use `checks[].status` for compact per-step tiles.
- Show `nextActions` to operators when dashboard sections are empty.

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
- When `count = 0`, the response includes `emptyReason`, `emptyMessage`,
  `operatorHints`, and `emptyScope`. Use those fields for operator-facing empty
  states instead of showing a generic "no data" message.

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
      "kind": "activity_event",
      "legacyKind": "run",
      "source": "apple-health",
      "externalId": "apple_health_...",
      "activityType": "running",
      "sourceRecordType": "activity_event",
      "name": "Apple Health Run",
      "startedAt": "2026-06-22T01:00:00Z",
      "endedAt": "2026-06-22T01:31:50Z",
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
        "maxHeartrate": 171,
        "averageCadence": 172,
        "calories": 380
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
- Use `kind = activity_event` and `activityType = running` for new UI code.
- `legacyKind = run` is retained for older consumers while the bridge is still run-focused.
- Use `metrics.distanceKm`, `metrics.movingTimeSec`, `metrics.pace`, `metrics.averageHeartrate`.
- Use `session.activityType` and `session.status` when `promoted=true`.
- Treat `dataClassification=PGHD` as client-generated/provider-originated data, not clinician-entered data.
- When `count = 0`, expect `emptyReason = "no_timeline_records"` plus
  `operatorHints` that point the operator toward PGHD connection mapping,
  provider ingest status, and over-narrow filters.

Privacy note:

- This endpoint intentionally does not return full `raw` provider payloads.
- It requires a scoped client filter to avoid accidental broad PGHD listing.

## Human State Snapshots

### `GET /api/run-log/state-snapshots`

Returns derived state values calculated from activity events or aggregate PGHD. This is the read surface for client profile signals such as adherence, training load, and fatigue.

At least one scoped client filter is required:

- `subject_person_id`
- `org_client_profile_id`

Other query:

- `organization_id`: optional UUID
- `state_type`: optional enum
- `source`: optional provider filter for persisted or weekly-derived state, for example `apple-health`
- `derive`: optional. Set `weekly` to calculate ad-hoc state signals from `run_log_weekly_summaries`
- `after`: optional `YYYY-MM-DD`
- `before`: optional `YYYY-MM-DD`
- `include_inputs`: optional boolean-like string, defaults to `true`
- `limit`: optional number, max 100, default 30

Accepted `state_type` values:

- `fitness`
- `fatigue`
- `recovery`
- `injury_risk`
- `adherence`
- `training_load`

Recommended physio_app call:

```http
GET /api/run-log/state-snapshots?subject_person_id=<person_id>&limit=12
Authorization: Bearer <token>
```

Recommended dashboard call before persisted state jobs exist:

```http
GET /api/run-log/state-snapshots?subject_person_id=<person_id>&derive=weekly&limit=12
Authorization: Bearer <token>
```

Response:

```json
{
  "ok": true,
  "source": "human-state-snapshots",
  "query": {
    "subjectPersonId": "person_uuid",
    "limit": 12
  },
  "snapshots": [
    {
      "id": "snapshot_uuid",
      "subjectPersonId": "person_uuid",
      "stateType": "fatigue",
      "value": 0.62,
      "confidence": 0.7,
      "calculatedAt": "2026-06-22T00:00:00Z",
      "windowStart": "2026-06-15T00:00:00Z",
      "windowEnd": "2026-06-22T00:00:00Z",
      "source": "run_log_weekly_summaries",
      "providerSource": "apple-health",
      "metadata": {
        "loadRatio": 1.5,
        "totalKmDelta": 6,
        "volumeTrend": "up",
        "dataQuality": "partial",
        "insufficientDataReasons": ["short_history"]
      },
      "inputs": [
        {
          "runLogRunId": "run_log_runs_uuid",
          "weight": 1,
          "activity": {
            "id": "run_log_runs_uuid",
            "source": "apple-health",
            "externalId": "provider_activity_id",
            "name": "Morning rehab run",
            "startedAt": "2026-06-18T01:00:00Z",
            "distanceKm": 4.02,
            "movingTimeSec": 1510,
            "pace": "6:15/km",
            "averageHeartrate": 142,
            "deviceName": "Apple Watch"
          }
        }
      ]
    }
  ],
  "count": 1
}
```

Empty response fields:

```json
{
  "ok": true,
  "source": "human-state-snapshots-derived",
  "derived": true,
  "query": {
    "subjectPersonId": "person_uuid",
    "sourceFilter": "apple-health",
    "limit": 12
  },
  "snapshots": [],
  "count": 0,
  "emptyReason": "no_derived_state_snapshots",
  "emptyMessage": "No derived Human State snapshots could be calculated from weekly PGHD activity summaries.",
  "operatorHints": [
    "Confirm at least one weekly summary exists for the requested subject_person_id.",
    "Confirm weekly summaries contain run_count, total_km, and moving_time_sec."
  ],
  "emptyScope": {
    "subjectPersonId": "person_uuid",
    "source": "apple-health"
  }
}
```

Fallback behavior:

- If `derive=weekly`, the endpoint does not require `human_state_snapshots` rows and returns `source = "human-state-snapshots-derived"`.
- If `derive=weekly`, the endpoint also attempts to attach source activity
  evidence from matching `run_log_runs` rows. Evidence enrichment is best-effort
  and the derived state response still succeeds when no matching run rows are
  available.
- If the `human_state_snapshots` table has not been migrated yet, the endpoint falls back to weekly derived signals instead of failing the dashboard.
- Persisted state rows should still be preferred once background state calculation jobs exist.
- The bundled dashboard first requests persisted snapshots, then falls back to `derive=weekly` when no persisted rows are available.
- `source` in the response identifies the calculation source. `providerSource` identifies the upstream PGHD provider used as input.
- The request `source` filter matches `providerSource`, so an unfiltered weekly derivation can return separate Apple Health and Strava state rows for the same subject and week.
- When persisted snapshot lookup returns no rows, the direct persisted response
  includes `emptyReason = "no_persisted_state_snapshots"`. The bundled dashboard
  then falls back to `derive=weekly`; if derived state is also empty, it renders
  the derived `emptyMessage` and `operatorHints`.

Render guidance:

- Treat `value` as a normalized 0-1 signal unless `metadata` states otherwise.
- Show `confidence` when a state is used for clinical review or decision support.
- Use `metadata.totalKmDelta`, `metadata.runCountDelta`, `metadata.volumeTrend`,
  and `metadata.adherenceTrend` to explain whether a state reflects current
  level only or a meaningful change from prior weeks.
- Use `inputs` for traceability, not for primary UI rendering. When available,
  `inputs[].activity` carries a compact source activity summary so professional
  review can see which run rows contributed to a state signal without querying
  `run_log_runs` separately.
- Do not present these values as diagnosis or treatment recommendations.

## Encounter Insights

### `GET /api/run-log/encounter-insights`

Returns encounter-ready review context derived from the latest human state
snapshots. This endpoint does not create clinical records and does not provide
diagnosis or treatment advice. It turns activity-derived state into review
prompts, evidence bullets, and suggested questions for the next professional
encounter.

At least one scoped client filter is required:

- `subject_person_id`
- `org_client_profile_id`

Other query:

- `organization_id`: optional UUID
- `source`: optional provider filter, for example `apple-health`
- `derive`: optional. Set `weekly` to force ad-hoc derivation from `run_log_weekly_summaries`
- `after`: optional `YYYY-MM-DD`
- `before`: optional `YYYY-MM-DD`
- `limit`: optional number, max 60, default 12

Recommended physio_app call:

```http
GET /api/run-log/encounter-insights?subject_person_id=<person_id>&limit=12
Authorization: Bearer <token>
```

Response:

```json
{
  "ok": true,
  "source": "encounter-insights",
  "derived": false,
  "insights": [
    {
      "insightType": "load_review",
      "severity": "alert",
      "title": "Review recent load before progressing the plan",
      "summary": "Fatigue is high enough that the next encounter should review recent volume, recovery, and symptoms before increasing training.",
      "providerSource": "apple-health",
      "confidence": 0.72,
      "evidence": [
        "fatigue 80%",
        "training load 68%",
        "load ratio 1.6",
        "weekly distance delta 14 km"
      ],
      "suggestedQuestions": [
        "Any soreness, pain, poor sleep, or unusual effort since the last run?"
      ],
      "suggestedActions": [
        "Review the source activity events before changing the plan."
      ],
      "noteDraft": "PGHD review: Review recent load before progressing the plan\nSeverity: alert\n\nSummary: Fatigue is high enough that the next encounter should review recent volume, recovery, and symptoms before increasing training.\n\nEvidence:\n- fatigue 80%\n- training load 68%\n- load ratio 1.6\n- weekly distance delta 14 km\n\nClinical note: PGHD-derived context only. Review with the client before changing the plan.",
      "sourceSnapshots": [
        {
          "id": "snapshot_uuid",
          "stateType": "fatigue",
          "value": 0.8,
          "providerSource": "apple-health",
          "volumeTrend": "up",
          "inputs": [
            {
              "runLogRunId": "run_log_run_uuid",
              "pghdActivityEventId": "pghd_activity_event_uuid",
              "weight": 1,
              "activity": {
                "name": "Morning rehab run",
                "startedAt": "2026-06-22T07:30:00.000Z",
                "distanceKm": 5.2,
                "paceSecPerKm": 370
              }
            }
          ]
        }
      ],
      "sourceActivities": [
        {
          "runLogRunId": "run_log_run_uuid",
          "pghdActivityEventId": "pghd_activity_event_uuid",
          "source": "apple-health",
          "externalId": "provider_activity_id",
          "name": "Morning rehab run",
          "startedAt": "2026-06-22T07:30:00.000Z",
          "distanceKm": 5.2,
          "movingTimeSec": 1924,
          "averageHeartrate": 142,
          "weight": 1
        }
      ]
    }
  ],
  "count": 1
}
```

Fallback behavior:

- Persisted `human_state_snapshots` are preferred.
- If persisted state rows are missing or `derive=weekly` is supplied, the endpoint derives weekly state snapshots and then builds insights.
- `source` filters the provider source, not the calculation source.

Render guidance:

- Show `severity`, `confidence`, and `evidence` together.
- Show one to three `sourceActivities` under each insight so the professional
  can verify the specific PGHD activity records before using the draft.
- Prefer insight evidence that includes state deltas/trends when available.
- Treat `noteDraft` as editable encounter-note starter text, not an accepted
  clinical note.
- Keep suggested questions editable by the professional user.
- Do not turn `suggestedActions` into automated care-plan changes without review.

### `POST /api/run-log/encounter-note-drafts`

Builds a PhysioApp-compatible `encounter_notes` draft export row from a reviewed
PGHD insight note. This endpoint intentionally does **not** insert into
`encounter_notes`; PhysioApp should persist the row through its authenticated
encounter/note workflow after professional review.

Required body:

```json
{
  "encounterId": "encounter_uuid",
  "organizationId": "organization_uuid",
  "subjectPersonId": "client_person_uuid",
  "providerPersonId": "provider_person_uuid",
  "editedNoteContent": "Reviewed PGHD note text"
}
```

Optional body:

- `insight`: one item from `GET /api/run-log/encounter-insights`
- `noteContent`: fallback note text if `editedNoteContent` is absent
- `noteFormat`: one of `soap`, `dap`, `wellness_note`, `training_log`; default `wellness_note`
- `isMedicalContext`: default `false`
- `requiresApproval`: default `true`

Response:

```json
{
  "ok": true,
  "source": "encounter-note-draft-export",
  "persisted": false,
  "draftExport": {
    "table": "encounter_notes",
    "mode": "draft_export",
    "upsertKey": ["encounter_id", "note_format"],
    "handoff": {
      "targetApp": "physio_app",
      "targetRepository": "createNoteRepository",
      "targetMethod": "upsert",
      "conflictTarget": "encounter_id,note_format",
      "persistVia": "authenticated server route/action",
      "reviewPolicy": "keep status=draft until professional sign-off"
    },
    "row": {
      "encounter_id": "encounter_uuid",
      "organization_id": "organization_uuid",
      "subject_person_id": "client_person_uuid",
      "provider_person_id": "provider_person_uuid",
      "note_format": "wellness_note",
      "status": "draft",
      "is_medical_context": false,
      "requires_approval": true,
      "note_content": "Reviewed PGHD note text",
      "source_system": "strava_run_log_pghd",
      "source_type": "pghd_encounter_insight",
      "ai_draft_snapshot": {
        "source_system": "strava_run_log_pghd",
        "source_type": "pghd_encounter_insight",
        "review_state": "draft_exported",
        "pghd_insight": {
          "insightType": "load_review",
          "severity": "warning",
          "sourceActivities": [
            {
              "runLogRunId": "run_log_run_uuid",
              "pghdActivityEventId": "pghd_activity_event_uuid",
              "name": "Morning rehab run",
              "startedAt": "2026-06-22T07:30:00.000Z",
              "distanceKm": 5.2
            }
          ]
        }
      },
      "discipline_sections": {
        "pghd_note_draft": {
          "source_system": "strava_run_log_pghd",
          "source_type": "pghd_encounter_insight",
          "review_state": "draft_exported"
        }
      }
    },
    "repositoryParams": {
      "encounter_id": "encounter_uuid",
      "organization_id": "organization_uuid",
      "subject_person_id": "client_person_uuid",
      "provider_person_id": "provider_person_uuid",
      "note_format": "wellness_note",
      "status": "draft",
      "is_medical_context": false,
      "requires_approval": true,
      "note_content": "Reviewed PGHD note text",
      "source_system": "strava_run_log_pghd",
      "source_type": "pghd_encounter_insight",
      "ai_draft_snapshot": {
        "source_system": "strava_run_log_pghd",
        "source_type": "pghd_encounter_insight",
        "review_state": "draft_exported",
        "pghd_insight": {
          "insightType": "load_review",
          "severity": "warning",
          "sourceActivities": [
            {
              "runLogRunId": "run_log_run_uuid",
              "pghdActivityEventId": "pghd_activity_event_uuid",
              "name": "Morning rehab run",
              "startedAt": "2026-06-22T07:30:00.000Z",
              "distanceKm": 5.2
            }
          ]
        }
      },
      "discipline_sections": {
        "pghd_note_draft": {
          "source_system": "strava_run_log_pghd",
          "source_type": "pghd_encounter_insight",
          "review_state": "draft_exported"
        }
      }
    }
  }
}
```

PhysioApp mapping:

- Target table: `encounter_notes`
- Upsert key: `encounter_id,note_format`
- Handoff target: POST to PhysioApp
  `/api/app/encounters/<encounterId>/pghd-note-draft` from an authenticated
  PhysioApp session, or call `createNoteRepository(...).upsert()` from an
  authenticated server route/action. Do not persist from the run-log dashboard
  or a public browser.
- Prefer `draftExport.repositoryParams` for that repository call. It includes
  the narrative note, `discipline_sections`, `source_system`, `source_type`, and
  `ai_draft_snapshot` fields needed to preserve PGHD provenance through
  PhysioApp's note repository.
- Do not put PGHD provenance JSON into `encounter_notes.data`; PhysioApp treats
  that column as DAP text. Provenance is carried in `ai_draft_snapshot` and in
  `discipline_sections.pghd_note_draft`.
- Preferred initial `note_format`: `wellness_note` or `training_log` unless a
  clinician deliberately maps it into SOAP/DAP.
- Keep `status = draft` until the existing PhysioApp sign-off workflow accepts
  or finalizes the note.

Dashboard behavior:

- The bundled dashboard lets the operator edit each `noteDraft`.
- If `encounterId`, `organizationId`, and `providerPersonId` are supplied, the
  dashboard can call this endpoint, show a `Draft export preview`, and copy both
  the full returned `draftExport` JSON and the narrower
  `draftExport.repositoryParams` upsert payload.
- The dashboard still does not persist clinical notes directly.

PhysioApp consume route:

```http
POST /api/app/encounters/<encounterId>/pghd-note-draft
X-Requested-With: XMLHttpRequest
Cookie: <authenticated PhysioApp session>
```

Accepted bodies:

```json
{ "repositoryParams": { "...": "draftExport.repositoryParams" } }
```

or:

```json
{ "draftExport": { "repositoryParams": { "...": "draftExport.repositoryParams" } } }
```

The route verifies the authenticated provider, note-write organization role
(`owner`, `admin`, or `provider`), and encounter
`organization_id`/`subject_person_id` before saving. Payload ids must match the
authenticated encounter context.

PhysioApp UI code should call the feature-local helper
`persistPghdNoteDraftFromRunLogExport({ encounterId, payload })`, which posts to
this route with the required `X-Requested-With` header and returns the saved
`noteId`, `noteFormat`, and `status`.

### `POST /api/run-log/state-snapshots`

Materializes derived weekly state signals into `human_state_snapshots`. Use this after the state snapshot migration has been applied and before a client dashboard should prefer persisted state over ad-hoc calculation.

Body:

```json
{
  "subject_person_id": "person_uuid",
  "source": "apple-health",
  "derive": "weekly",
  "limit": 12
}
```

Required:

- `subject_person_id` or `org_client_profile_id`

Optional:

- `organization_id`
- `org_client_profile_id`
- `source`
- `state_type`
- `after`
- `before`
- `limit`
- `derive`: currently only `weekly`

Behavior:

- Reads `run_log_weekly_summaries`.
- Calculates `training_load`, `adherence`, and `fatigue`.
- Deletes existing rows for the same subject/calculation source/provider source/window/state combination.
- Inserts replacement rows into `human_state_snapshots`.
- Links persisted snapshots back to source `run_log_runs` rows in `human_state_snapshot_inputs` when matching activity events are available for the calculation window.
- Returns `409` if the state snapshot migration has not been applied.

Response:

```json
{
  "ok": true,
  "source": "human-state-snapshots",
  "persisted": true,
  "replaced": true,
  "snapshots": [
    {
      "id": "snapshot_uuid",
      "subjectPersonId": "person_uuid",
      "stateType": "training_load",
      "value": 0.42,
      "confidence": 0.65,
      "source": "run_log_weekly_summaries",
      "providerSource": "apple-health",
      "inputs": [
        {
          "runLogRunId": "run_log_runs_uuid",
          "weight": 1
        }
      ]
    }
  ],
  "count": 3
}
```

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
   - `GET /api/run-log/state-snapshots?subject_person_id=<person_id>&limit=12`
4. UI renders:
   - weekly distance/time/pace/HR trend
   - timeline cards
   - adherence/training load/fatigue signals
   - linked/unlinked status
5. If the operator wants to persist current state signals after migration, server calls:
   - `POST /api/run-log/state-snapshots`
6. If an unlinked run should become a workflow activity, server calls:
   - `POST /api/run-log/promote-to-activity-session`
7. UI refreshes timeline and state signals.

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
npm run check:pghd:migration-history
npm run check:pghd:state-functional
npm run check:pghd:state-schema
npm run smoke:pghd:state:db
npm run smoke:pghd:state
npm run smoke:pghd
npm run smoke:pghd:db
```

Expected:

- API unit tests pass
- State schema check passes after `20260622145528_add_activity_event_state_snapshots.sql` is applied to the linked Supabase project
- State DB smoke verifies the activity-event columns, state snapshot natural key, and snapshot input join table, then deletes its smoke rows
- State smoke inserts a `state-smoke` run, materializes weekly state snapshots, verifies persisted input traceability links, reads them back, then deletes smoke rows
- E2E smoke inserts an Apple Health run, verifies weekly summary, checks PGHD
  preflight readiness, verifies derived state signals, promotes it, verifies
  timeline, then deletes smoke rows
- E2E smoke output includes `evidence.preflightChecks`,
  `evidence.preflightWarnings`, and `evidence.preflightNextActions` so operators
  can see why a preflight warning occurred without replaying the request
- E2E smoke output also includes `evidence.connectionSelectionMode` and
  `evidence.selectedOrgClientContext` so operators can tell whether the smoke
  used an encounter-handoff-ready org client subject or a fallback PGHD subject
- Use `PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT=1 npm run smoke:pghd` in staging
  when fallback PGHD subjects without `org_clients` context should fail the gate
- If staging has no reusable org-client PGHD subject, use
  `npm run smoke:pghd:strict-org-client`.
  This creates a temporary PhysioApp `persons`, `organization_members`,
  `org_clients`, and `pghd_connections` fixture. Smoke cleanup deletes the
  temporary connection/client membership rows and tombstones the temporary
  person because PhysioApp person lifecycle triggers do not support hard delete
  for this flow. Optional `PGHD_SMOKE_ORGANIZATION_ID` and
  `PGHD_SMOKE_PROVIDER_PERSON_ID` can pin the organization/provider; otherwise
  the script picks one active provider/staff membership.
- Use `npm run smoke:pghd:strict-full` when the gate should also persist
  temporary Human State snapshots before preflight. This option is intentionally
  allowed only with `PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT` so the smoke does not
  replace state snapshots for an existing real client.
- Use `npm run gate:pghd:strict-staging` when staging should prove strict-full
  PGHD preflight plus the static PhysioApp handoff surface and smoke cleanup in
  one command.
- Use `npm run check:pghd:smoke-cleanup` to verify no bootstrap PGHD
  connections, Apple Health smoke runs, or active PGHD smoke persons remain.
- DB smoke verifies insert/view/link behavior inside a rolled-back transaction

If `npm run check:pghd:state-schema` fails with missing `activity_type` or `human_state_snapshots`, apply the pending migration to the linked project:

```bash
SUPABASE_DB_PASSWORD=<remote-db-password> npm run apply:pghd:state-migration
```

The workflow script first runs migration-history preflight. It only continues to
the Supabase list/push steps when `dbPushBlocked`, pending migrations, and
missing migrations are all clear:

```bash
npm run check:pghd:migration-history
supabase migration list --linked
supabase db push --linked --yes
supabase migration list --linked
PGHD_SCHEMA_CHECK_RETRIES=10 npm run check:pghd:state-schema
npm run smoke:pghd:state:db
npm run smoke:pghd:state
```

If `npm run check:pghd:migration-history` reports `dbPushBlocked: true`, the linked Supabase project has remote migration history entries that are not present in this repo. `supabase db push` will refuse to run in that state. The checker prints `nextActions`; the safe order is to fetch missing remote history first, then only repair PGHD local-only versions after schema and smoke checks prove that SQL is already present on the linked database. Do not run `supabase migration repair` automatically from this project.

Before running any repair command, generate a read-only operator plan:

```bash
npm run plan:pghd:migration-reconciliation
```

This runs migration-history inspection plus the PGHD state functional checks and
marks repair actions eligible only when functional proof exists.

To execute the eligible fetch/focused repair workflow, use the guarded command
with an explicit confirmation token:

```bash
PGHD_MIGRATION_RECONCILE_APPLY=20260622145528 npm run apply:pghd:migration-reconciliation
```

Without that token, the workflow fails before changing remote migration
history. When it does run, it fetches linked remote history first, then repairs
only the PGHD local-only versions marked eligible by the plan. It does not run
broad `supabase db push`.

When the functional schema must be applied without changing migration history, use the guarded direct SQL fallback:

```bash
PGHD_DIRECT_SQL_APPLY=20260622145528 npm run apply:pghd:state-sql-direct
```

This runs the idempotent state SQL through `supabase db query --linked --file`, then runs state schema readiness and state smokes. It does not repair or update Supabase migration history.

To verify only the functional state path after direct SQL apply, run:

```bash
npm run check:pghd:state-functional
```

To inspect both functional readiness and Supabase migration history readiness:

```bash
npm run check:pghd:status
```

The status output separates `preflightSurfaceOk`, `functionalOk`, and
`migrationHistoryOk`. `preflightSurfaceOk` is a local contract coverage check
for the preflight endpoint, dashboard panel, bridge contract, API contract, and
E2E smoke hook.

`migrationHistoryOk: true` can mean either the local migration history is fully
reconciled or the PhysioApp owner-lineage bridge migration has been applied.
Always inspect `localMigrationHistoryOk`, `ownerBridgeApplied`, and
`dbPushBlocked` before choosing an apply path. The top-level
`recommendedApplyPath` and `dbPushAllowed` fields summarize that decision for
operators. When `dbPushBlocked: true`, normal `supabase db push` from
`strava-run-log` remains off-limits even if `ownerBridgeApplied: true`.

To run the release gate for the currently accepted apply path:

```bash
npm run check:pghd:release-readiness
```

This gate combines `check:pghd:status` with the read-only reconciliation plan
and fails if there is no verified apply path.

If you apply the migration manually, rerun:

```bash
PGHD_SCHEMA_CHECK_RETRIES=10 npm run check:pghd:state-schema
npm run smoke:pghd:state:db
npm run smoke:pghd:state
```

## Integration Decision

Short term:

- physio_app calls this bridge API from server-side code.

Medium term:

- Move the timeline API shape into physio_app if both apps share deployment/runtime.

Long term:

- Keep provider ingest adapters independent, but make physio_app the primary owner of client PGHD timeline rendering.
