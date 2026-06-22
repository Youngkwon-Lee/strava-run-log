export const BRIDGE_CONTRACT_VERSION = '2026-06-22';

export function buildBridgeContract(origin = '') {
  const baseUrl = String(origin || '').replace(/\/$/, '');
  const endpoint = (path) => (baseUrl ? `${baseUrl}${path}` : path);

  return {
    ok: true,
    contractVersion: BRIDGE_CONTRACT_VERSION,
    product: 'strava-run-log',
    purpose: 'Apple Health and Apple Watch bridge contract for run history ingest and live coaching.',
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
      }
    },
    clientGuidance: {
      idempotency: 'Use a stable external_run_id per workout. Re-sending the same id updates the stored run.',
      healthKit: 'HealthKit authorization must happen inside the iOS app. This web service only receives data after consent.',
      liveRun: 'Push live metrics every 5-15 seconds, but rely on nextCheckSec/cooldown for user-facing coaching frequency.',
      privacy: 'Only send fields needed for coaching or client timeline display.'
    }
  };
}
