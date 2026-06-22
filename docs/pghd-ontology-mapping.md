# PGHD and Ontology Mapping

## Decision

The running data ingested from Strava, Apple Health, Garmin, Apple Watch LiveRun, and GPX/TCX imports should be treated as **PGHD: patient-generated health data** once it is used in the Kinnero/physio app context.

Keep two layers:

1. `public.run_log_runs`
   - Provider-originated PGHD staging table.
   - Stores source-normalized run history and compact raw payload.
   - Idempotent by `(source, external_id)`.
   - Can exist before the person is mapped to a physio app client.

2. `public.activity_sessions`
   - Professional workflow record.
   - Created only after a run is attached to `subject_person_id` and optionally `organization_id`, `org_client_profile_id`, `episode_id`, `encounter_id`, or `care_plan_id`.
   - This is the better long-term surface for dashboards used by clinicians, coaches, or rehab professionals.

In short: data lands as PGHD in `run_log_runs`; it becomes a physio workflow activity when promoted into `activity_sessions`.

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
| `source` | `run_log_runs` | Origin system | `Observation.meta.source` or identifier system |
| `external_id` | `run_log_runs` | Stable idempotency key | `Observation.identifier` |
| `user_id` | `run_log_runs.raw` | App/account user before clinical mapping | Patient/account mapping input |
| `subject_person_id` | `run_log_runs`, `activity_sessions` | Mapped physio app person | `Observation.subject -> Patient` |
| `deviceName`, `device_source` | `raw` | Capturing wearable/app | `Observation.device -> Device` |
| `startDate`, `startedAt`, `endedAt` | `run_log_runs` | Activity period | `Observation.effectivePeriod` |
| `distanceMeters` | `raw`, metrics | Workout distance | Activity Observation component, UCUM `m` |
| `movingTimeSec` | `run_log_runs` | Active duration | Activity Observation component, UCUM `s` |
| `paceSecPerKm` | `raw`, metrics | Derived pace | Open mHealth pace or local coded component |
| `averageHeartrate` | `run_log_runs` | Average HR during activity | FHIR Observation, LOINC `8867-4` when atomic |
| `calories` | `raw` | Energy burned | FHIR Observation, LOINC `41981-2` |
| `route_points` | `raw` or future telemetry store | Location time series | Open mHealth geoposition or separate telemetry object |
| weekly moderate minutes | report summary | Activity guideline progress | HL7 Physical Activity IG Exercise Vital Sign |

## What Not To Do

- Do not store dense GPS or per-second watch telemetry directly in `run_log_runs.raw` long term.
- Do not treat raw provider data as a clinical diagnosis.
- Do not write directly into `activity_sessions` until a client/person mapping exists.
- Do not collapse provider identity, app user identity, and physio client identity into one field.

## Implementation Notes

- `GET /api/bridge/contract` exposes `dataClassification.category = "PGHD"` and a compact `ontologyMapping` block for bridge clients.
- `POST /api/run-log/promote-to-activity-session` is the current boundary-crossing endpoint from provider PGHD into physio workflow records.
- If a future FHIR export is needed, generate FHIR Bundles from `run_log_runs`/`activity_sessions` rather than making FHIR the internal write model too early.

## Sources

- ONC PGHD resource: https://healthit.gov/resources/infographic-what-are-patient-generated-health-data-pghd/
- HHS/ASPE PGHD infrastructure paper: https://aspe.hhs.gov/conceptualizing-data-infrastructure-capture-use-patient-generated-health-data
- HL7 FHIR Observation R4: https://hl7.org/fhir/R4/observation.html
- HL7 Personal Health Device IG: https://build.fhir.org/ig/HL7/phd/
- HL7 Physical Activity IG example: https://build.fhir.org/ig/HL7/physical-activity/Observation-ExampleEVSMinutesPerWeek.html
- Open mHealth to FHIR IG: https://healthedata1.github.io/mFHIR/
- WHO physical activity fact sheet: https://www.who.int/news-room/fact-sheets/detail/physical-activity
