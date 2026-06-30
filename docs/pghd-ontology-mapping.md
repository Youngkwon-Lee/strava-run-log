# PGHD and Ontology Mapping

## Decision

The running data ingested from Strava, Apple Health, Garmin, Apple Watch LiveRun, and GPX/TCX imports should be treated as **PGHD: patient-generated health data** once it is used in the Kinnero/physio app context.

Keep three layers:

1. `public.pghd_activity_events`
   - Provider-originated generic PGHD activity-event staging table.
   - Stores source-normalized activity history, compact metrics, and compact raw payload.
   - Idempotent by `(source, external_id)`.
   - Can exist before the person is mapped to a physio app client.
   - Represents the activity event input layer across running, walking, cycling, rehab exercise, and wearable summaries.

2. `public.run_log_runs`
   - Running-specific projection and compatibility layer.
   - Links to `pghd_activity_events.id` through `pghd_activity_event_id` when available.
   - Keeps existing dashboard, weekly summary, timeline, and state derivation contracts stable while the generic event layer expands.

3. `public.human_state_snapshots`
   - Derived human state values calculated from activity events and related PGHD.
   - Stores state types such as training load, adherence, fatigue, recovery, fitness, and injury risk.
   - Keeps calculation source and provider source separate.
   - Uses `public.human_state_snapshot_inputs` for traceability back to source activity events.

4. `public.activity_sessions`
   - Professional workflow record.
   - Created only after a run is attached to `subject_person_id` and optionally `organization_id`, `org_client_profile_id`, `episode_id`, `encounter_id`, or `care_plan_id`.
   - This is the better long-term surface for dashboards used by clinicians, coaches, or rehab professionals.

In short: data lands as PGHD activity events in `pghd_activity_events`; running data is projected into `run_log_runs`; it can be interpreted into human state signals in `human_state_snapshots`; it becomes a physio workflow activity only when promoted into `activity_sessions`.

## Source Rationale

- ONC and HHS PGHD materials define PGHD around health-related data created or recorded by/from patients outside clinical settings to help address a health concern.
- HL7 FHIR `Observation` is the primary interoperable shape for measurements and simple assertions about a patient, device, or other subject. It supports categories, codes, subject, effective time, value, performer, and device references.
- HL7 Physical Activity IG models Exercise Vital Sign observations such as days/week and minutes/week for moderate-to-strenuous activity.
- HL7 Personal Health Device IG is relevant when the data is device-originated and needs device measurement provenance.
- Open mHealth to FHIR maps mobile/wearable schemas into FHIR resources, typically Observations, and includes physical-activity concepts such as steps, calories, geoposition, pace, speed, and moderate activity minutes.
- WHO physical activity guidance gives the product a population-health framing for weekly moderate activity minutes, but it is not a clinical diagnosis model.

## Local to Interoperability Mapping

| Local field / concept | Local table | PGHD meaning | FHIR / ontology target |
| --- | --- | --- | --- |
| `source` | `pghd_activity_events`, `run_log_runs` | Origin system | `Observation.meta.source` or identifier system |
| `external_id` | `pghd_activity_events`, `run_log_runs` | Stable idempotency key | `Observation.identifier` |
| `user_id` | `pghd_activity_events.raw`, `run_log_runs.raw` | App/account user before clinical mapping | Patient/account mapping input |
| `subject_person_id` | `pghd_activity_events`, `run_log_runs`, `activity_sessions` | Mapped physio app person | `Observation.subject -> Patient` |
| `deviceName`, `device_source` | `raw` | Capturing wearable/app | `Observation.device -> Device` |
| `startDate`, `startedAt`, `endedAt` | `pghd_activity_events`, `run_log_runs` | Activity period | `Observation.effectivePeriod` |
| `distanceMeters` | `raw`, metrics | Workout distance | Activity Observation component, UCUM `m` |
| `movingTimeSec` | `pghd_activity_events`, `run_log_runs` | Active duration | Activity Observation component, UCUM `s` |
| `paceSecPerKm` | `raw`, metrics | Derived pace | Open mHealth pace or local coded component |
| `averageHeartrate` | `pghd_activity_events`, `run_log_runs` | Average HR during activity | FHIR Observation, LOINC `8867-4` when atomic |
| `calories` | `raw` | Energy burned | FHIR Observation, LOINC `41981-2` |
| `route_points` | `raw` or future telemetry store | Location time series | Open mHealth geoposition or separate telemetry object |
| weekly moderate minutes | report summary | Activity guideline progress | HL7 Physical Activity IG Exercise Vital Sign |
| `state_type`, `value`, `confidence` | `human_state_snapshots` | Derived human state assertion | FHIR Observation with local code and provenance |
| `provider_source` | `human_state_snapshots` | Upstream PGHD provider used as state input | Observation.derivedFrom / provenance source |

## What Not To Do

- Do not store dense GPS or per-second watch telemetry directly in `pghd_activity_events.raw` or `run_log_runs.raw` long term.
- Do not treat raw provider data as a clinical diagnosis.
- Do not write directly into `activity_sessions` until a client/person mapping exists.
- Do not store fatigue, adherence, training load, recovery, or risk values on `run_log_runs`; keep them in `human_state_snapshots`.
- Do not collapse provider identity, app user identity, and physio client identity into one field.

## Implementation Notes

- `GET /api/bridge/contract` exposes `dataClassification.category = "PGHD"` and a compact `ontologyMapping` block for bridge clients.
- `POST /api/run-log/promote-to-activity-session` is the current boundary-crossing endpoint from provider PGHD into physio workflow records.
- `GET/POST /api/run-log/state-snapshots` exposes or materializes the current derived human state layer.
- If a future FHIR export is needed, generate FHIR Bundles from `run_log_runs`, `human_state_snapshots`, and `activity_sessions` rather than making FHIR the internal write model too early.
- For the current `moai_web` table boundary audit, see [`pghd-table-boundary-audit.md`](pghd-table-boundary-audit.md).

## Sources

- ONC PGHD resource: https://healthit.gov/resources/infographic-what-are-patient-generated-health-data-pghd/
- HHS/ASPE PGHD infrastructure paper: https://aspe.hhs.gov/conceptualizing-data-infrastructure-capture-use-patient-generated-health-data
- HL7 FHIR Observation R4: https://hl7.org/fhir/R4/observation.html
- HL7 Personal Health Device IG: https://build.fhir.org/ig/HL7/phd/
- HL7 Physical Activity IG example: https://build.fhir.org/ig/HL7/physical-activity/Observation-ExampleEVSMinutesPerWeek.html
- Open mHealth to FHIR IG: https://healthedata1.github.io/mFHIR/
- WHO physical activity fact sheet: https://www.who.int/news-room/fact-sheets/detail/physical-activity
