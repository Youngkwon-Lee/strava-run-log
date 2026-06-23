export const BRIDGE_CONTRACT_VERSION = '2026-06-22';

export function buildBridgeContract(origin = '') {
  const baseUrl = String(origin || '').replace(/\/$/, '');
  const endpoint = (path) => (baseUrl ? `${baseUrl}${path}` : path);

  return {
    ok: true,
    contractVersion: BRIDGE_CONTRACT_VERSION,
    product: 'strava-run-log',
    purpose:
      'PGHD bridge contract for activity-event ingest, live coaching, derived human state, encounter insight, and reviewed note draft export.',
    dataClassification: {
      category: 'PGHD',
      label: 'patient-generated health data',
      rationale:
        'Provider and wearable activity data is created or captured by the client outside the clinical setting and can be used by the professional workflow after consent and person mapping.',
      storageBoundary: {
        runLogRuns: 'provider-originated PGHD staging and normalized run history',
        activitySessions: 'clinician/workflow-attached activity record after subject_person_id mapping',
        humanStateSnapshots: 'derived weekly state signals calculated from activity events',
        encounterNoteDrafts:
          'reviewed export payload for PhysioApp encounter_notes; not persisted by strava-run-log'
      }
    },
    ontologyMapping: {
      fhir: {
        workoutSession: 'Observation category=activity, or Procedure/ActivitySession in local workflow when attached to a care context',
        heartRate: 'Observation code=http://loinc.org|8867-4 Heart rate',
        stepCount: 'Observation code=http://loinc.org|55423-8 Number of steps in unspecified time Pedometer',
        caloriesBurned: 'Observation code=http://loinc.org|41981-2 Calories burned',
        exerciseMinutesPerWeek: 'Physical Activity IG Exercise Vital Sign minutes per week',
        device: 'Device referenced from Observation.device when source device identity is available'
      },
      openMHealth: {
        distance: 'omh:physical-activity / workout summary distance',
        pace: 'omh:pace',
        speed: 'omh:speed',
        caloriesBurned: 'omh:calories-burned',
        geoposition: 'omh:geoposition',
        moderateActivityMinutes: 'omh:minutes-moderate-activity'
      },
      localFields: {
        source: 'run_log_runs.source',
        externalId: 'run_log_runs.external_id',
        subjectPersonId: 'run_log_runs.subject_person_id when linked to physio app person',
        summaryPayload: 'run_log_runs.raw',
        workflowSession: 'activity_sessions.id after promotion'
      }
    },
    auth: {
      appleHealthIngest: {
        tokenEnv: 'APPLE_HEALTH_INGEST_TOKEN',
        acceptedHeaders: ['Authorization: Bearer <token>', 'x-api-key: <token>'],
        optionalSignatureEnv: 'APPLE_HEALTH_SIGNING_SECRET',
        optionalSignatureHeader: 'x-signature: HMAC_SHA256_HEX(rawBody)'
      },
      liveMetrics: {
        tokenEnv: 'LIVE_METRICS_TOKEN',
        acceptedHeaders: [
          'Authorization: Bearer <token>',
          'x-live-metrics-token: <token>',
          'x-live-token: <token>'
        ]
      },
      runLogAdmin: {
        tokenEnv: 'RUN_LOG_ADMIN_TOKEN',
        acceptedHeaders: ['Authorization: Bearer <token>', 'x-run-log-token: <token>'],
        note:
          'Server/admin surface for PGHD state, encounter insight, and draft export. Do not expose service-role keys to public clients.'
      }
    },
    endpoints: {
      appleHealthIngest: {
        method: 'POST',
        url: endpoint('/api/apple-health/ingest'),
        contentType: 'application/json',
        storesRunHistory: true,
        requiredFields: {
          external_run_id: 'string, stable idempotency key from the mobile app',
          started_at: 'ISO-8601 timestamp',
          ended_at: 'ISO-8601 timestamp after started_at',
          distance_m: 'number, meters',
          moving_time_s: 'number, seconds'
        },
        optionalFields: {
          user_id: 'string',
          elapsed_time_s: 'number, seconds',
          elevation_gain_m: 'number, meters',
          avg_hr: 'number, bpm',
          max_hr: 'number, bpm',
          cadence_avg: 'number, steps per minute',
          calories: 'number',
          device_source: 'string, e.g. Apple Watch Ultra',
          source_app: 'string, e.g. Apple Health',
          splits: 'array of { km, moving_time_s, avg_hr?, max_hr? }',
          route_points: 'array of { lat, lng, altitude_m?, distance_m?, hr?, recorded_at? }',
          send_to_discord: 'boolean, default true'
        },
        responseFields: ['ok', 'id', 'source', 'contractVersion', 'summary', 'coaching', 'stored', 'accepted']
      },
      liveMetrics: {
        method: 'POST',
        url: endpoint('/api/live/metrics'),
        contentType: 'application/json',
        storesRunHistory: false,
        requiredFields: {},
        optionalFields: {
          session_id: 'string, defaults to default',
          user_id: 'string, defaults to default',
          pace_sec: 'number, seconds per km, 0 means unavailable',
          gap_sec: 'number, grade-adjusted pace seconds per km',
          hr: 'number, bpm',
          distance_km: 'number, kilometers',
          elapsed_sec: 'number, seconds',
          cadence: 'number, steps per minute',
          readiness_score: 'number, 0-100',
          force: 'boolean, bypass cooldown'
        },
        responseFields: [
          'ok',
          'sent',
          'coaching',
          'severity',
          'action',
          'nextCheckSec',
          'adjustedTargetPaceSec',
          'contractVersion'
        ]
      },
      stateSnapshots: {
        methods: ['GET', 'POST'],
        url: endpoint('/api/run-log/state-snapshots'),
        contentType: 'application/json',
        storesRunHistory: false,
        persistsDerivedState: 'POST materializes weekly state snapshots when the Supabase state tables exist',
        requiredQueryOrBody: {
          subject_person_id: 'UUID, required unless org_client_profile_id is supplied',
          org_client_profile_id: 'UUID, required unless subject_person_id is supplied'
        },
        optionalFields: {
          source: 'provider filter such as apple-health or strava; maps to providerSource',
          derive: 'weekly for ad-hoc calculation from run_log_weekly_summaries',
          state_type: 'fitness | fatigue | recovery | injury_risk | adherence | training_load',
          limit: 'number, default 30 for GET'
        },
        responseFields: ['ok', 'source', 'snapshots', 'count']
      },
      encounterInsights: {
        method: 'GET',
        url: endpoint('/api/run-log/encounter-insights'),
        contentType: 'application/json',
        storesRunHistory: false,
        persistsClinicalNotes: false,
        requiredQuery: {
          subject_person_id: 'UUID, required unless org_client_profile_id is supplied',
          org_client_profile_id: 'UUID, required unless subject_person_id is supplied'
        },
        optionalFields: {
          source: 'provider filter such as apple-health or strava',
          derive: 'weekly to force ad-hoc state derivation',
          limit: 'number, max 60, default 12'
        },
        responseFields: ['ok', 'source', 'derived', 'insights', 'count']
      },
      pghdPreflight: {
        method: 'GET',
        url: endpoint('/api/run-log/preflight'),
        contentType: 'application/json',
        storesRunHistory: false,
        persistsClinicalNotes: false,
        requiredQuery: {
          subject_person_id: 'UUID client/person'
        },
        optionalFields: {
          source: 'provider filter such as apple-health or strava',
          limit: 'number, max 20, default 5'
        },
        responseFields: ['ok', 'source', 'query', 'summary', 'checks', 'nextActions']
      },
      encounterNoteDrafts: {
        method: 'POST',
        url: endpoint('/api/run-log/encounter-note-drafts'),
        contentType: 'application/json',
        storesRunHistory: false,
        persistsClinicalNotes: false,
        requiredFields: {
          encounterId: 'UUID from PhysioApp encounters',
          organizationId: 'UUID from PhysioApp organizations',
          subjectPersonId: 'UUID client/person',
          providerPersonId: 'UUID provider/person',
          editedNoteContent: 'reviewed note text, or provide noteContent / insight.noteDraft'
        },
        optionalFields: {
          insight: 'one item from encounterInsights response',
          noteFormat: 'soap | dap | wellness_note | training_log, default wellness_note',
          isMedicalContext: 'boolean, default false',
          requiresApproval: 'boolean, default true'
        },
        responseFields: ['ok', 'source', 'persisted', 'draftExport', 'message']
      }
    },
    clientGuidance: {
      idempotency: 'Use a stable external_run_id per workout. Re-sending the same id updates the stored run.',
      healthKit: 'HealthKit authorization must happen inside the iOS app. This web service only receives data after consent.',
      liveRun: 'Push live metrics every 5-15 seconds, but rely on nextCheckSec/cooldown for user-facing coaching frequency.',
      pghdState:
        'Use state snapshots and encounter insights as review context. Do not present them as diagnosis or autonomous treatment advice.',
      noteExport:
        'encounterNoteDrafts returns a PhysioApp-compatible draft export row only. Persist through the authenticated PhysioApp note workflow.',
      privacy: 'Only send fields needed for coaching, client timeline display, state review, or professional note drafting.'
    }
  };
}
