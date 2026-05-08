import assert from 'node:assert/strict';
import { afterEach, mock, test } from 'node:test';

const restoreEnvFns = [];

afterEach(() => {
  mock.restoreAll();
  while (restoreEnvFns.length) restoreEnvFns.pop()();
});

function createMockResponse() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
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

async function importFresh(path) {
  return import(`${path}?t=${Date.now()}-${Math.random()}`);
}

test('live metrics rejects unsupported methods', async () => {
  const { default: handler } = await importFresh('../api/live/metrics.js');

  const res = await callHandler(handler, { method: 'GET', body: {}, query: {} });

  assert.equal(res.statusCode, 405);
  assert.deepEqual(res.body, { error: 'method not allowed' });
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
  withEnv({
    STRAVA_ACCESS_TOKEN: 'access-token',
    STRAVA_TOKEN_EXPIRES_AT: Math.floor(Date.now() / 1000) + 3600,
    DISCORD_WEBHOOK_URL: undefined
  });
  const { default: handler } = await importFresh('../api/strava/webhook.js');

  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.match(String(url), /\/api\/v3\/activities\/12345$/);
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

test('weekly report summarizes recent Strava runs', async () => {
  withEnv({
    STRAVA_ACCESS_TOKEN: 'access-token',
    STRAVA_TOKEN_EXPIRES_AT: Math.floor(Date.now() / 1000) + 3600,
    DISCORD_WEBHOOK_URL: undefined
  });
  const { default: handler } = await importFresh('../api/strava/weekly-report.js');

  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.match(String(url), /\/api\/v3\/athlete\/activities\?/);
    assert.equal(options.headers.Authorization, 'Bearer access-token');
    return Response.json([
      { type: 'Run', distance: 5000, moving_time: 1800 },
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
  assert.deepEqual(res.body, {
    ok: true,
    summary: {
      runCount: 2,
      totalKm: 12.5,
      moderateMinutes: 75,
      whoTargetMin: 150,
      whoTargetMax: 300,
      progressToMinPct: 50,
      status: 'below_minimum'
    }
  });
  assert.equal(fetchMock.mock.callCount(), 1);
});
