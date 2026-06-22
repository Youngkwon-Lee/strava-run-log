import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, mock, test } from 'node:test';

const restoreEnvFns = [];
const cleanupDirs = [];

afterEach(async () => {
  mock.restoreAll();
  while (restoreEnvFns.length) restoreEnvFns.pop()();
  while (cleanupDirs.length) {
    await rm(cleanupDirs.pop(), { recursive: true, force: true });
  }
});

function createMockResponse() {
  return {
    statusCode: 200,
    headers: {},
    ended: false,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    setHeader(name, value) {
      this.headers[name.toLowerCase()] = value;
      return this;
    },
    getHeader(name) {
      return this.headers[name.toLowerCase()];
    },
    end() {
      this.ended = true;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    }
  };
}

async function callHandler(handler, req) {
  const res = createMockResponse();
  await handler(req, res);
  return res;
}

function setEnv(values) {
  const previous = new Map();

  for (const [key, value] of Object.entries(values)) {
    previous.set(key, process.env[key]);
    if (value === undefined) delete process.env[key];
    else process.env[key] = String(value);
  }

  return () => {
    for (const [key, value] of previous.entries()) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
}

function withEnv(values) {
  const restore = setEnv(values);
  restoreEnvFns.push(restore);
}

async function withTempRunStore() {
  const dir = await mkdtemp(join(tmpdir(), 'strava-run-log-test-'));
  cleanupDirs.push(dir);
  withEnv({ RUN_STORE_PATH: join(dir, 'runs.jsonl') });
}

async function importFresh(path) {
  return import(`${path}?t=${Date.now()}-${Math.random()}`);
}

function cookieHeaderFromSetCookie(setCookie) {
  return [setCookie]
    .flat()
    .filter(Boolean)
    .map((cookie) => String(cookie).split(';')[0])
    .join('; ');
}

test('live metrics rejects unsupported methods', async () => {
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, { method: 'GET', body: {}, query: {} });

  assert.equal(res.statusCode, 405);
  assert.deepEqual(res.body, { error: 'method not allowed' });
});

test('bridge contract exposes Apple Health and LiveRun payload contract', async () => {
  withEnv({ PUBLIC_BASE_URL: 'https://example.test' });
  const { default: handler } = await importFresh('../api/bridge/contract.js');

  const res = await callHandler(handler, {
    method: 'GET',
    headers: {},
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.contractVersion, '2026-06-22');
  assert.equal(res.body.dataClassification.category, 'PGHD');
  assert.equal(res.body.dataClassification.storageBoundary.runLogRuns, 'provider-originated PGHD staging and normalized run history');
  assert.equal(res.body.ontologyMapping.fhir.heartRate, 'Observation code=http://loinc.org|8867-4 Heart rate');
  assert.equal(res.body.ontologyMapping.openMHealth.pace, 'omh:pace');
  assert.equal(res.body.endpoints.appleHealthIngest.url, 'https://example.test/api/apple-health/ingest');
  assert.equal(res.body.endpoints.appleHealthIngest.requiredFields.external_run_id, 'string, stable idempotency key from the mobile app');
  assert.equal(res.body.endpoints.liveMetrics.url, 'https://example.test/api/live/metrics');
  assert.equal(res.body.endpoints.liveMetrics.optionalFields.pace_sec, 'number, seconds per km, 0 means unavailable');
  assert.deepEqual(res.body.auth.liveMetrics.acceptedHeaders, [
    'Authorization: Bearer <token>',
    'x-live-metrics-token: <token>',
    'x-live-token: <token>'
  ]);
});

test('live metrics rejects missing auth when token is configured', async () => {
  withEnv({ LIVE_METRICS_TOKEN: 'bridge-secret' });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      session_id: 'api-live-auth-missing',
      pace_sec: 370,
      distance_km: 1.0,
      elapsed_sec: 360
    }
  });

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'unauthorized' });
});

test('live metrics accepts bearer token auth', async () => {
  withEnv({ LIVE_METRICS_TOKEN: 'bridge-secret' });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: { Authorization: 'Bearer bridge-secret' },
    query: {},
    body: {
      session_id: 'api-live-auth-bearer',
      pace_sec: 370,
      distance_km: 1.0,
      elapsed_sec: 360
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.contractVersion, '2026-06-22');
  assert.equal(res.body.sent, true);
});

test('live metrics accepts x-live-metrics-token auth', async () => {
  withEnv({ LIVE_METRICS_TOKEN: 'bridge-secret' });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: { 'x-live-metrics-token': 'bridge-secret' },
    query: {},
    body: {
      session_id: 'api-live-auth-header',
      pace_sec: 370,
      distance_km: 1.0,
      elapsed_sec: 360
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.sent, true);
});

test('live metrics accepts run-live-coach x-live-token auth', async () => {
  withEnv({ LIVE_METRICS_TOKEN: 'bridge-secret' });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: { 'x-live-token': 'bridge-secret' },
    query: {},
    body: {
      session_id: 'api-live-auth-legacy-header',
      pace_sec: 370,
      distance_km: 1.0,
      elapsed_sec: 360
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.sent, true);
});

test('live metrics rejects invalid sensor payloads', async () => {
  withEnv({ LIVE_METRICS_TOKEN: undefined });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      session_id: 'api-live-invalid',
      pace_sec: 'fast',
      hr: 300,
      distance_km: -1,
      elapsed_sec: 360
    }
  });

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'invalid request');
  assert.match(res.body.details.join('\n'), /pace_sec must be a finite number/);
  assert.match(res.body.details.join('\n'), /hr must be between 0 and 240/);
  assert.match(res.body.details.join('\n'), /distance_km must be between 0 and 200/);
});

test('live metrics rejects invalid force values', async () => {
  withEnv({ LIVE_METRICS_TOKEN: undefined });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      session_id: 'api-live-invalid-force',
      pace_sec: 370,
      distance_km: 1.0,
      elapsed_sec: 360,
      force: 'sometimes'
    }
  });

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'invalid request');
  assert.match(res.body.details.join('\n'), /force must be a boolean/);
});

test('live metrics parses string force values without treating false as true', async () => {
  withEnv({ LIVE_METRICS_TOKEN: undefined });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const req = {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      session_id: 'api-live-force-string',
      pace_sec: 370,
      distance_km: 1.0,
      elapsed_sec: 360,
      force: 'false'
    }
  };

  const first = await callHandler(handler, req);
  const second = await callHandler(handler, req);

  assert.equal(first.statusCode, 200);
  assert.equal(first.body.sent, true);
  assert.equal(second.statusCode, 200);
  assert.equal(second.body.sent, false);
});

test('live metrics returns coaching and observes cooldown', async () => {
  withEnv({ LIVE_METRICS_TOKEN: undefined });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const req = {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      session_id: 'api-live-cooldown',
      user_id: 'youngkwon',
      pace_sec: 340,
      hr: 150,
      distance_km: 1.2,
      elapsed_sec: 420
    }
  };

  const first = await callHandler(handler, req);
  const second = await callHandler(handler, req);

  assert.equal(first.statusCode, 200);
  assert.equal(first.body.ok, true);
  assert.equal(first.body.sent, true);
  assert.equal(first.body.action, 'slow_down');
  assert.equal(first.body.severity, 'warn');

  assert.equal(second.statusCode, 200);
  assert.equal(second.body.sent, false);
});

test('live metrics suppresses simulator sessions from Discord by default', async () => {
  withEnv({
    LIVE_METRICS_TOKEN: undefined,
    ALLOW_SIM_DISCORD_POSTS: undefined
  });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      session_id: 'sim-api-live',
      pace_sec: 345,
      hr: 151,
      distance_km: 1.1,
      elapsed_sec: 300,
      force: true
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.sent, false);
  assert.equal(res.body.action, 'slow_down');
});

test('live metrics can opt simulator sessions into Discord posts', async () => {
  withEnv({
    LIVE_METRICS_TOKEN: undefined,
    ALLOW_SIM_DISCORD_POSTS: 'true'
  });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      session_id: 'sim-api-live-opt-in',
      pace_sec: 345,
      hr: 151,
      distance_km: 1.1,
      elapsed_sec: 300,
      force: true
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.sent, true);
});

test('live metrics applies user profile settings from env', async () => {
  withEnv({
    LIVE_METRICS_TOKEN: undefined,
    COACH_USER_PROFILES_JSON: JSON.stringify({
      mother: {
        target_pace_sec: 620,
        max_hr: 145,
        hr_sustained_sec: 90,
        coaching_frequency_sec: 120,
        readiness_score: 65
      }
    })
  });
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, {
    method: 'POST',
    query: {},
    body: {
      session_id: 'api-live-profile',
      user_id: 'mother',
      pace_sec: 628,
      hr: 130,
      distance_km: 1.0,
      elapsed_sec: 360
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.nextCheckSec, 120);
  assert.equal(res.body.adjustedTargetPaceSec, 628);
  assert.equal(res.body.action, 'maintain');
});

test('webhook verification returns Strava challenge', async () => {
  withEnv({ STRAVA_VERIFY_TOKEN: 'verify-me' });
  const { default: handler } = await importFresh('../api/strava/webhook.js');

  const res = await callHandler(handler, {
    method: 'GET',
    body: {},
    query: {
      'hub.mode': 'subscribe',
      'hub.verify_token': 'verify-me',
      'hub.challenge': 'challenge-123'
    }
  });

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { 'hub.challenge': 'challenge-123' });
});

test('webhook ignores non-activity events', async () => {
  const { default: handler } = await importFresh('../api/strava/webhook.js');

  const res = await callHandler(handler, {
    method: 'POST',
    query: {},
    body: { object_type: 'athlete', aspect_type: 'update' }
  });

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { ok: true, ignored: true });
});

test('webhook fetches activity details for activity create events', async () => {
  await withTempRunStore();
  withEnv({
    STRAVA_ACCESS_TOKEN: 'access-token',
    STRAVA_TOKEN_EXPIRES_AT: Math.floor(Date.now() / 1000) + 3600,
    DISCORD_WEBHOOK_URL: undefined
  });
  const { default: handler } = await importFresh('../api/strava/webhook.js');

  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.match(String(url), /\/api\/v3\/activities\/12345\?include_all_efforts=true$/);
    assert.equal(options.headers.Authorization, 'Bearer access-token');
    return Response.json({
      id: 12345,
      name: 'Morning Run',
      distance: 5000,
      moving_time: 1850,
      total_elevation_gain: 42,
      average_heartrate: 150,
      splits_metric: []
    });
  });

  const res = await callHandler(handler, {
    method: 'POST',
    query: {},
    body: { object_type: 'activity', aspect_type: 'create', object_id: 12345 }
  });

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { ok: true });
  assert.equal(fetchMock.mock.callCount(), 1);
});

test('integration providers exposes provider rollout status', async () => {
  const { default: handler } = await importFresh('../api/integrations/providers.js');

  const res = await callHandler(handler, {
    method: 'GET',
    headers: {},
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.deepEqual(res.body.rollout.directOAuth, ['strava']);
  assert.deepEqual(res.body.rollout.mobileBridgeRequired, ['apple-health']);
  assert.deepEqual(res.body.rollout.bridgeBackendReady, ['apple-health', 'liverun-watch']);
  assert.deepEqual(res.body.rollout.requiresPartnerApproval, ['garmin']);
  assert.deepEqual(res.body.rollout.manualImportPlanned, ['file-import']);

  const providerById = Object.fromEntries(res.body.providers.map((provider) => [provider.id, provider]));
  assert.equal(providerById.strava.status, 'live');
  assert.equal(providerById.strava.actionLabel, 'Strava 연결');
  assert.equal(providerById['apple-health'].status, 'mobile_app_required');
  assert.equal(providerById['apple-health'].actionLabel, 'Apple 건강 앱 연결');
  assert.equal(providerById.garmin.status, 'partner_review_required');
  assert.equal(providerById.garmin.actionLabel, 'Garmin 연결');
  assert.equal(providerById['liverun-watch'].status, 'watch_bridge_ready');
  assert.equal(providerById['liverun-watch'].actionLabel, 'Apple Watch LiveRun 연결');
  assert.equal(providerById['file-import'].status, 'manual_import_planned');
  assert.equal(providerById['file-import'].actionLabel, 'GPX/FIT/TCX 업로드');
  assert.equal(providerById['nike-run-club'].status, 'no_public_api');
});

test('apple health ingest rejects unauthorized requests', async () => {
  withEnv({ APPLE_HEALTH_INGEST_TOKEN: 'apple-secret' });
  const { default: handler } = await importFresh('../api/apple-health/ingest.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'unauthorized' });
});

test('apple health ingest validates signature and returns normalized summary', async () => {
  await withTempRunStore();
  withEnv({
    APPLE_HEALTH_INGEST_TOKEN: 'apple-secret',
    APPLE_HEALTH_SIGNING_SECRET: 'apple-signing-secret',
    DISCORD_WEBHOOK_URL: undefined,
    COACH_TARGET_PACE_SEC: '370'
  });
  const { default: handler } = await importFresh('../api/apple-health/ingest.js');

  const body = {
    external_run_id: 'apple_health_TEST-001',
    user_id: 'youngkwon',
    started_at: '2026-05-25T06:12:10Z',
    ended_at: '2026-05-25T06:43:29Z',
    distance_m: 5540.8,
    moving_time_s: 1879,
    elapsed_time_s: 1890,
    elevation_gain_m: 36.1,
    avg_hr: 165.1,
    max_hr: 185,
    cadence_avg: 174,
    calories: 432,
    device_source: 'Apple Watch Ultra',
    source_app: 'Apple Health',
    splits: [
      { km: 1, moving_time_s: 351, avg_hr: 153.2 },
      { km: 2, moving_time_s: 338, avg_hr: 162.1 }
    ]
  };
  const rawBody = JSON.stringify(body);
  const signature = createHmac('sha256', 'apple-signing-secret').update(rawBody).digest('hex');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer apple-secret',
      'x-signature': signature
    },
    rawBody,
    query: {},
    body
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.id, 'apple_health_TEST-001');
  assert.equal(res.body.source, 'apple-health');
  assert.equal(res.body.summary.distanceKm, 5.54);
  assert.equal(res.body.summary.pace, '5:39/km');
  assert.equal(res.body.accepted.splitCount, 2);
  assert.equal(res.body.accepted.routePointCount, 0);
  assert.equal(res.body.stored.inserted, true);
  assert.equal(res.body.stored.count, 1);
  assert.equal(res.body.postedToDiscord, false);
  assert.match(res.body.coaching, /코칭:/);
});

test('apple health ingest rejects invalid signature', async () => {
  withEnv({
    APPLE_HEALTH_INGEST_TOKEN: 'apple-secret',
    APPLE_HEALTH_SIGNING_SECRET: 'apple-signing-secret'
  });
  const { default: handler } = await importFresh('../api/apple-health/ingest.js');

  const body = {
    external_run_id: 'apple_health_BADSIG',
    started_at: '2026-05-25T06:12:10Z',
    ended_at: '2026-05-25T06:43:29Z',
    distance_m: 5540.8,
    moving_time_s: 1879
  };

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer apple-secret',
      'x-signature': 'bad-signature'
    },
    rawBody: JSON.stringify(body),
    query: {},
    body
  });

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'invalid signature' });
});

test('run file import stores GPX runs', async () => {
  await withTempRunStore();
  const { default: handler } = await importFresh('../api/import/run-file.js');
  const { readStoredRuns } = await importFresh('../lib/run-store.js');

  const gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Morning test run</name>
    <trkseg>
      <trkpt lat="37.5665" lon="126.9780">
        <ele>20</ele>
        <time>2026-06-22T06:00:00Z</time>
        <extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>142</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions>
      </trkpt>
      <trkpt lat="37.5675" lon="126.9890">
        <ele>24</ele>
        <time>2026-06-22T06:05:00Z</time>
        <extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>150</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions>
      </trkpt>
      <trkpt lat="37.5685" lon="127.0000">
        <ele>28</ele>
        <time>2026-06-22T06:10:00Z</time>
        <extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>156</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions>
      </trkpt>
    </trkseg>
  </trk>
</gpx>`;

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      filename: 'morning.gpx',
      format: 'gpx',
      content: gpx
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.source, 'file-import');
  assert.equal(res.body.summary.name, 'Morning test run');
  assert.equal(res.body.summary.fileFormat, 'gpx');
  assert.equal(res.body.summary.routePointCount, 3);
  assert.ok(res.body.summary.distanceKm > 1.8);

  const runs = await readStoredRuns();
  assert.equal(runs.length, 1);
  assert.equal(runs[0].source, 'file-import');
  assert.equal(runs[0].name, 'Morning test run');
  assert.equal(runs[0].routePointCount, 3);
});

test('run file import rejects FIT until binary parser is enabled', async () => {
  const { default: handler } = await importFresh('../api/import/run-file.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {
      filename: 'run.fit',
      format: 'fit',
      contentBase64: Buffer.from('FITDATA').toString('base64')
    }
  });

  assert.equal(res.statusCode, 415);
  assert.match(res.body.error, /FIT import requires/);
});

test('stored activities include Apple Health ingests without Strava auth', async () => {
  await withTempRunStore();
  withEnv({
    APPLE_HEALTH_INGEST_TOKEN: 'apple-secret',
    DISCORD_WEBHOOK_URL: undefined
  });

  const body = {
    external_run_id: 'apple_health_STORE-001',
    user_id: 'youngkwon',
    started_at: '2026-06-20T06:00:00Z',
    ended_at: '2026-06-20T06:31:00Z',
    distance_m: 5000,
    moving_time_s: 1800,
    elevation_gain_m: 25,
    avg_hr: 150,
    cadence_avg: 172,
    send_to_discord: false
  };

  const { default: ingestHandler } = await importFresh('../api/apple-health/ingest.js');
  const ingestRes = await callHandler(ingestHandler, {
    method: 'POST',
    headers: { Authorization: 'Bearer apple-secret' },
    query: {},
    body
  });

  assert.equal(ingestRes.statusCode, 200);
  assert.equal(ingestRes.body.stored.inserted, true);

  const { default: activitiesHandler } = await importFresh('../api/strava/activities.js');
  const activitiesRes = await callHandler(activitiesHandler, {
    method: 'GET',
    headers: {},
    query: { source: 'stored', days: '30', limit: '5' },
    body: {}
  });

  assert.equal(activitiesRes.statusCode, 200);
  assert.equal(activitiesRes.body.source, 'stored');
  assert.equal(activitiesRes.body.authMode, 'run-store');
  assert.equal(activitiesRes.body.summary.totalKm, 5);
  assert.equal(activitiesRes.body.activities[0].source, 'apple-health');
  assert.equal(activitiesRes.body.activities[0].pace, '6:00/km');

  const { default: weeklyHandler } = await importFresh('../api/strava/weekly-report.js');
  const weeklyRes = await callHandler(weeklyHandler, {
    method: 'GET',
    headers: {},
    query: { source: 'stored' },
    body: {}
  });

  assert.equal(weeklyRes.statusCode, 200);
  assert.equal(weeklyRes.body.source, 'stored');
  assert.equal(weeklyRes.body.summary.runCount, 1);
  assert.equal(weeklyRes.body.summary.totalKm, 5);
  assert.equal(weeklyRes.body.runs[0].source, 'apple-health');
});

test('run-log promotion requires admin auth', async () => {
  withEnv({ RUN_LOG_ADMIN_TOKEN: 'admin-secret' });
  const { default: handler } = await importFresh('../api/run-log/promote-to-activity-session.js');

  const res = await callHandler(handler, {
    method: 'POST',
    headers: {},
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'unauthorized' });
});

test('run-log promotion creates an activity session and links the run', async () => {
  withEnv({
    RUN_LOG_ADMIN_TOKEN: 'admin-secret',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });
  const { default: handler } = await importFresh('../api/run-log/promote-to-activity-session.js');

  const subjectPersonId = '11111111-1111-4111-8111-111111111111';
  const activitySessionId = '22222222-2222-4222-8222-222222222222';
  const calls = [];
  const fetchMock = mock.method(globalThis, 'fetch', async (url, options = {}) => {
    calls.push({ url: String(url), options });
    assert.equal(options.headers.apikey, 'service-role-key');
    assert.equal(options.headers.authorization, 'Bearer service-role-key');

    const href = String(url);
    if (href.includes('/rest/v1/run_log_runs?') && !options.method) {
      assert.match(href, /source=eq\.apple-health/);
      assert.match(href, /external_id=eq\.apple-001/);
      return Response.json([
        {
          source: 'apple-health',
          external_id: 'apple-001',
          user_id: 'youngkwon',
          name: 'Morning Run',
          start_date: '2026-06-22T01:00:00Z',
          distance_meters: 4020,
          moving_time_sec: 1510,
          pace_sec_per_km: 376,
          average_heartrate: 142,
          average_cadence: 171,
          raw: {
            distanceKm: 4.02,
            pace: '6:16/km',
            totalElevationGainMeters: 12.5
          }
        }
      ]);
    }

    if (href.endsWith('/rest/v1/activity_sessions') && options.method === 'POST') {
      const body = JSON.parse(options.body);
      assert.equal(body.subject_person_id, subjectPersonId);
      assert.equal(body.activity_type, 'other');
      assert.equal(body.source, 'apple_health');
      assert.equal(body.status, 'completed');
      assert.equal(body.performed_at, '2026-06-22T01:00:00Z');
      assert.equal(body.duration_seconds, 1510);
      assert.equal(body.metrics.distance_meters, 4020);
      assert.equal(body.exercise_log.provider_external_id, 'apple-001');
      return Response.json([{ id: activitySessionId }]);
    }

    if (href.includes('/rest/v1/run_log_runs?') && options.method === 'PATCH') {
      const body = JSON.parse(options.body);
      assert.equal(body.subject_person_id, subjectPersonId);
      assert.equal(body.activity_session_id, activitySessionId);
      assert.ok(body.linked_at);
      return Response.json([
        {
          source: 'apple-health',
          external_id: 'apple-001',
          subject_person_id: subjectPersonId,
          activity_session_id: activitySessionId
        }
      ]);
    }

    throw new Error(`unexpected fetch: ${href}`);
  });

  const res = await callHandler(handler, {
    method: 'POST',
    headers: { authorization: 'Bearer admin-secret' },
    query: {},
    body: {
      source: 'apple-health',
      external_id: 'apple-001',
      subject_person_id: subjectPersonId
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.activitySessionId, activitySessionId);
  assert.equal(res.body.run.subjectPersonId, subjectPersonId);
  assert.equal(fetchMock.mock.callCount(), 3);
  assert.equal(calls[0].options.method, undefined);
  assert.equal(calls[1].options.method, 'POST');
  assert.equal(calls[2].options.method, 'PATCH');
});

test('run-log promotion resolves subject person from PGHD connection', async () => {
  withEnv({
    RUN_LOG_ADMIN_TOKEN: 'admin-secret',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });
  const { default: handler } = await importFresh('../api/run-log/promote-to-activity-session.js');

  const subjectPersonId = '11111111-1111-4111-8111-111111111111';
  const activitySessionId = '22222222-2222-4222-8222-222222222222';
  const fetchMock = mock.method(globalThis, 'fetch', async (url, options = {}) => {
    const href = String(url);

    if (href.includes('/rest/v1/run_log_runs?') && !options.method) {
      return Response.json([
        {
          source: 'apple-health',
          external_id: 'apple-001',
          user_id: 'youngkwon',
          name: 'Morning Run',
          start_date: '2026-06-22T01:00:00Z',
          distance_meters: 4020,
          moving_time_sec: 1510,
          raw: {
            userId: 'youngkwon',
            distanceKm: 4.02
          }
        }
      ]);
    }

    if (href.includes('/rest/v1/pghd_connections?')) {
      assert.match(href, /provider=in\.%28apple-health%2Capple_health%29/);
      assert.match(href, /provider_user_id=in\.%28youngkwon%29/);
      return Response.json([
        {
          id: '33333333-3333-4333-8333-333333333333',
          person_id: subjectPersonId,
          provider: 'apple-health',
          provider_user_id: 'youngkwon',
          connection_status: 'active'
        }
      ]);
    }

    if (href.endsWith('/rest/v1/activity_sessions') && options.method === 'POST') {
      const body = JSON.parse(options.body);
      assert.equal(body.subject_person_id, subjectPersonId);
      return Response.json([{ id: activitySessionId }]);
    }

    if (href.includes('/rest/v1/run_log_runs?') && options.method === 'PATCH') {
      const body = JSON.parse(options.body);
      assert.equal(body.subject_person_id, subjectPersonId);
      assert.equal(body.activity_session_id, activitySessionId);
      return Response.json([
        {
          source: 'apple-health',
          external_id: 'apple-001',
          subject_person_id: subjectPersonId,
          activity_session_id: activitySessionId
        }
      ]);
    }

    throw new Error(`unexpected fetch: ${href}`);
  });

  const res = await callHandler(handler, {
    method: 'POST',
    headers: { authorization: 'Bearer admin-secret' },
    query: {},
    body: {
      source: 'apple-health',
      external_id: 'apple-001'
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.activitySessionId, activitySessionId);
  assert.equal(res.body.run.subjectPersonId, subjectPersonId);
  assert.equal(fetchMock.mock.callCount(), 4);
});

test('run-log weekly summaries requires admin auth', async () => {
  withEnv({ RUN_LOG_ADMIN_TOKEN: 'admin-secret' });
  const { default: handler } = await importFresh('../api/run-log/weekly-summaries.js');

  const res = await callHandler(handler, {
    method: 'GET',
    headers: {},
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'unauthorized' });
});

test('run-log weekly summaries reads Supabase view with filters', async () => {
  withEnv({
    RUN_LOG_ADMIN_TOKEN: 'admin-secret',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });
  const { default: handler } = await importFresh('../api/run-log/weekly-summaries.js');

  const subjectPersonId = '11111111-1111-4111-8111-111111111111';
  const fetchMock = mock.method(globalThis, 'fetch', async (url, options = {}) => {
    const href = String(url);
    assert.match(href, /\/rest\/v1\/run_log_weekly_summaries\?/);
    assert.match(href, /subject_person_id=eq\.11111111-1111-4111-8111-111111111111/);
    assert.match(href, /source=eq\.apple-health/);
    assert.match(href, /limit=12/);
    assert.equal(options.headers.apikey, 'service-role-key');
    assert.equal(options.headers.authorization, 'Bearer service-role-key');
    return Response.json([
      {
        week_start: '2026-06-15',
        subject_person_id: subjectPersonId,
        source: 'apple-health',
        run_count: 3,
        total_km: 18.2,
        moderate_minutes: 105,
        average_pace_sec_per_km: 346
      }
    ]);
  });

  const res = await callHandler(handler, {
    method: 'GET',
    headers: { authorization: 'Bearer admin-secret' },
    query: {
      subject_person_id: subjectPersonId,
      source: 'apple-health',
      limit: '12'
    },
    body: {}
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.count, 1);
  assert.equal(res.body.summaries[0].total_km, 18.2);
  assert.equal(fetchMock.mock.callCount(), 1);
});

test('PGHD connections requires admin auth', async () => {
  withEnv({ RUN_LOG_ADMIN_TOKEN: 'admin-secret' });
  const { default: handler } = await importFresh('../api/pghd/connections.js');

  const res = await callHandler(handler, {
    method: 'GET',
    headers: {},
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'unauthorized' });
});

test('PGHD connections upserts provider mapping', async () => {
  withEnv({
    RUN_LOG_ADMIN_TOKEN: 'admin-secret',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });
  const { default: handler } = await importFresh('../api/pghd/connections.js');

  const personId = '11111111-1111-4111-8111-111111111111';
  const fetchMock = mock.method(globalThis, 'fetch', async (url, options = {}) => {
    const href = String(url);
    assert.match(href, /\/rest\/v1\/pghd_connections\?on_conflict=person_id%2Cprovider$/);
    assert.equal(options.method, 'POST');
    assert.equal(options.headers.Prefer, 'resolution=merge-duplicates,return=representation');
    const body = JSON.parse(options.body);
    assert.equal(body.person_id, personId);
    assert.equal(body.provider, 'apple-health');
    assert.equal(body.provider_user_id, 'youngkwon');
    assert.equal(body.connection_status, 'active');
    return Response.json([{ id: '22222222-2222-4222-8222-222222222222', ...body }]);
  });

  const res = await callHandler(handler, {
    method: 'POST',
    headers: { authorization: 'Bearer admin-secret' },
    query: {},
    body: {
      person_id: personId,
      provider: 'apple_health',
      provider_user_id: 'youngkwon',
      metadata: { source: 'test' }
    }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.connection.provider, 'apple-health');
  assert.equal(fetchMock.mock.callCount(), 1);
});

test('PGHD connections lists provider mappings', async () => {
  withEnv({
    RUN_LOG_ADMIN_TOKEN: 'admin-secret',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });
  const { default: handler } = await importFresh('../api/pghd/connections.js');

  const personId = '11111111-1111-4111-8111-111111111111';
  const fetchMock = mock.method(globalThis, 'fetch', async (url, options = {}) => {
    const href = String(url);
    assert.match(href, /\/rest\/v1\/pghd_connections\?/);
    assert.match(href, /person_id=eq\.11111111-1111-4111-8111-111111111111/);
    assert.match(href, /provider=eq\.strava/);
    assert.equal(options.headers.apikey, 'service-role-key');
    return Response.json([
      {
        id: '22222222-2222-4222-8222-222222222222',
        person_id: personId,
        provider: 'strava',
        provider_user_id: '12345',
        connection_status: 'active'
      }
    ]);
  });

  const res = await callHandler(handler, {
    method: 'GET',
    headers: { authorization: 'Bearer admin-secret' },
    query: {
      person_id: personId,
      provider: 'strava'
    },
    body: {}
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.count, 1);
  assert.equal(res.body.connections[0].provider_user_id, '12345');
  assert.equal(fetchMock.mock.callCount(), 1);
});

test('strava connect redirects to OAuth and sets state cookie', async () => {
  withEnv({
    STRAVA_CLIENT_ID: '12345',
    STRAVA_CLIENT_SECRET: 'client-secret',
    STRAVA_SESSION_SECRET: 'session-secret'
  });
  const { default: handler } = await importFresh('../api/strava/connect.js');

  const res = await callHandler(handler, {
    method: 'GET',
    headers: { host: 'example.test', 'x-forwarded-proto': 'https' },
    query: { return_to: '/settings.html' },
    body: {}
  });

  assert.equal(res.statusCode, 302);
  assert.match(res.headers.location, /^https:\/\/www\.strava\.com\/oauth\/authorize\?/);
  assert.match(res.headers.location, /client_id=12345/);
  assert.match(res.headers.location, /scope=read%2Cactivity%3Aread%2Cactivity%3Aread_all/);
  assert.match(String(res.headers['set-cookie']), /strava_run_log_oauth_state=/);
});

test('strava callback stores a user OAuth session cookie', async () => {
  withEnv({
    STRAVA_CLIENT_ID: '12345',
    STRAVA_CLIENT_SECRET: 'client-secret',
    STRAVA_SESSION_SECRET: 'session-secret'
  });
  const { default: connectHandler } = await importFresh('../api/strava/connect.js');
  const connectRes = await callHandler(connectHandler, {
    method: 'GET',
    headers: { host: 'example.test', 'x-forwarded-proto': 'https' },
    query: { return_to: '/settings.html' },
    body: {}
  });
  const state = new URL(connectRes.headers.location).searchParams.get('state');

  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(String(url), 'https://www.strava.com/oauth/token');
    const body = String(options.body);
    assert.match(body, /grant_type=authorization_code/);
    assert.match(body, /code=oauth-code/);
    return Response.json({
      access_token: 'user-access',
      refresh_token: 'user-refresh',
      expires_at: Math.floor(Date.now() / 1000) + 3600,
      scope: 'read,activity:read,activity:read_all',
      athlete: {
        id: 777,
        username: 'runner',
        firstname: 'Test',
        lastname: 'Runner',
        profile_medium: 'https://example.test/profile.jpg'
      }
    });
  });

  const { default: callbackHandler } = await importFresh('../api/strava/callback.js');
  const callbackRes = await callHandler(callbackHandler, {
    method: 'GET',
    headers: {
      host: 'example.test',
      'x-forwarded-proto': 'https',
      cookie: cookieHeaderFromSetCookie(connectRes.headers['set-cookie'])
    },
    query: { code: 'oauth-code', state },
    body: {}
  });

  assert.equal(callbackRes.statusCode, 302);
  assert.equal(callbackRes.headers.location, '/settings.html?strava=connected');
  assert.match(String(callbackRes.headers['set-cookie']), /strava_run_log_session=/);
  assert.equal(fetchMock.mock.callCount(), 1);

  const { default: meHandler } = await importFresh('../api/strava/me.js');
  const meRes = await callHandler(meHandler, {
    method: 'GET',
    headers: { cookie: cookieHeaderFromSetCookie(callbackRes.headers['set-cookie']) },
    query: {},
    body: {}
  });

  assert.equal(meRes.statusCode, 200);
  assert.equal(meRes.body.connected, true);
  assert.equal(meRes.body.session.athlete.id, 777);
  assert.equal(meRes.body.session.hasActivityReadAll, true);
  assert.equal(meRes.body.session.accessToken, undefined);
});

test('strava activities requires user OAuth session by default', async () => {
  withEnv({
    STRAVA_ACCESS_TOKEN: 'access-token',
    STRAVA_TOKEN_EXPIRES_AT: Math.floor(Date.now() / 1000) + 3600,
    STRAVA_ALLOW_SERVER_FALLBACK: undefined
  });
  const { default: handler } = await importFresh('../api/strava/activities.js');

  const res = await callHandler(handler, {
    method: 'GET',
    headers: {},
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'Strava account is not connected' });
});

test('strava activities endpoint returns rich run details and optional streams', async () => {
  await withTempRunStore();
  withEnv({
    STRAVA_ACCESS_TOKEN: 'access-token',
    STRAVA_TOKEN_EXPIRES_AT: Math.floor(Date.now() / 1000) + 3600,
    STRAVA_ALLOW_SERVER_FALLBACK: 'true'
  });
  const { default: handler } = await importFresh('../api/strava/activities.js');

  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(options.headers.Authorization, 'Bearer access-token');
    const href = String(url);

    if (href.includes('/api/v3/athlete/activities?')) {
      assert.match(href, /per_page=100/);
      return Response.json([
        { id: 123, type: 'Run', sport_type: 'Run', distance: 5000, moving_time: 1800 },
        { id: 124, type: 'Run', sport_type: 'Run', distance: 10, moving_time: 5 },
        { id: 999, type: 'Ride', sport_type: 'Ride', distance: 20000, moving_time: 3600 }
      ]);
    }

    if (href.endsWith('/api/v3/activities/123?include_all_efforts=true')) {
      return Response.json({
        id: 123,
        name: 'Evening Run',
        type: 'Run',
        sport_type: 'Run',
        distance: 5000,
        moving_time: 1800,
        elapsed_time: 1850,
        total_elevation_gain: 42,
        average_heartrate: 151,
        average_cadence: 174,
        calories: 310,
        map: { summary_polyline: 'abc123' },
        splits_metric: [{ split: 1, distance: 1000, moving_time: 360 }],
        laps: [{ id: 1, name: 'Lap 1', distance: 5000, moving_time: 1800 }]
      });
    }

    if (href.includes('/api/v3/activities/123/streams?')) {
      assert.match(href, /keys=/);
      return Response.json({
        latlng: { type: 'latlng', data: [[37.1, 127.1], [37.2, 127.2]] },
        distance: { type: 'distance', data: [0, 5000] },
        time: { type: 'time', data: [0, 1800] },
        heartrate: { type: 'heartrate', data: [145, 156] },
        cadence: { type: 'cadence', data: [170, 176] }
      });
    }

    throw new Error(`unexpected fetch: ${href}`);
  });

  const res = await callHandler(handler, {
    method: 'GET',
    query: { days: '30', limit: '5', streams: 'true' },
    body: {}
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.fetched.activityCount, 3);
  assert.equal(res.body.fetched.runCount, 1);
  assert.equal(res.body.fetched.ignoredShortRunCount, 1);
  assert.equal(res.body.summary.totalKm, 5);
  assert.equal(res.body.summary.averagePace, '6:00/km');
  assert.equal(res.body.activities[0].name, 'Evening Run');
  assert.equal(res.body.activities[0].pace, '6:00/km');
  assert.equal(res.body.activities[0].map.summaryPolyline, 'abc123');
  assert.equal(res.body.activities[0].streamSummary.pointCount, 2);
  assert.equal(res.body.activities[0].streams.latlng.data.length, 2);
  assert.equal(fetchMock.mock.callCount(), 3);
});

test('weekly report summarizes recent Strava runs', async () => {
  await withTempRunStore();
  withEnv({
    STRAVA_ACCESS_TOKEN: 'access-token',
    STRAVA_TOKEN_EXPIRES_AT: Math.floor(Date.now() / 1000) + 3600,
    STRAVA_ALLOW_SERVER_FALLBACK: 'true',
    DISCORD_WEBHOOK_URL: undefined
  });
  const { default: handler } = await importFresh('../api/strava/weekly-report.js');

  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.match(String(url), /\/api\/v3\/athlete\/activities\?/);
    assert.equal(options.headers.Authorization, 'Bearer access-token');
    return Response.json([
      { type: 'Run', distance: 5000, moving_time: 1800 },
      { type: 'Run', distance: 10, moving_time: 5 },
      { sport_type: 'Run', distance: 7500, moving_time: 2700 },
      { type: 'Ride', distance: 20000, moving_time: 3600 }
    ]);
  });

  const res = await callHandler(handler, {
    method: 'GET',
    query: {},
    body: {}
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.source, 'strava');
  assert.equal(res.body.window.days, 7);
  assert.match(res.body.window.afterIso, /^\d{4}-\d{2}-\d{2}T/);
  assert.deepEqual(res.body.summary, {
    runCount: 2,
    totalKm: 12.5,
    moderateMinutes: 75,
    whoTargetMin: 150,
    whoTargetMax: 300,
    progressToMinPct: 50,
    status: 'below_minimum',
    averagePace: '6:00/km',
    totalElevationGainMeters: 0,
    longestRun: {
      distanceKm: 7.5,
      movingTime: '45:00',
      pace: '6:00/km'
    }
  });
  assert.deepEqual(res.body.runs, [
    {
      type: 'Run',
      distanceMeters: 5000,
      distanceKm: 5,
      movingTimeSec: 1800,
      movingTime: '30:00',
      elapsedTime: '0:00',
      paceSecPerKm: 360,
      pace: '6:00/km'
    },
    {
      sportType: 'Run',
      distanceMeters: 7500,
      distanceKm: 7.5,
      movingTimeSec: 2700,
      movingTime: '45:00',
      elapsedTime: '0:00',
      paceSecPerKm: 360,
      pace: '6:00/km'
    }
  ]);
  assert.equal(fetchMock.mock.callCount(), 1);
});
