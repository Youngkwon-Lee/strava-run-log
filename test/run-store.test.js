import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { mock, test, afterEach } from 'node:test';

const restoreEnvFns = [];
const cleanupDirs = [];

afterEach(async () => {
  mock.restoreAll();
  while (restoreEnvFns.length) restoreEnvFns.pop()();
  while (cleanupDirs.length) {
    await rm(cleanupDirs.pop(), { recursive: true, force: true });
  }
});

function setEnv(values) {
  const previous = new Map();

  for (const [key, value] of Object.entries(values)) {
    previous.set(key, process.env[key]);
    if (value === undefined) delete process.env[key];
    else process.env[key] = String(value);
  }

  restoreEnvFns.push(() => {
    for (const [key, value] of previous.entries()) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
}

async function importFresh(path) {
  return import(`${path}?t=${Date.now()}-${Math.random()}`);
}

async function tempRunStorePath() {
  const dir = await mkdtemp(join(tmpdir(), 'strava-run-store-test-'));
  cleanupDirs.push(dir);
  return join(dir, 'runs.jsonl');
}

test('Supabase run store reads rows through PostgREST', async () => {
  setEnv({
    RUN_STORE_BACKEND: 'supabase',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });

  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.match(String(url), /^https:\/\/project\.supabase\.co\/rest\/v1\/run_log_runs\?/);
    assert.match(String(url), /select=/);
    assert.match(String(url), /order=start_date\.desc\.nullslast/);
    assert.equal(options.headers.apikey, 'service-role-key');
    assert.equal(options.headers.authorization, 'Bearer service-role-key');
    return Response.json([
      {
        source: 'apple-health',
        external_id: 'apple-001',
        start_date: '2026-06-20T06:00:00Z',
        distance_meters: 5000,
        moving_time_sec: 1800,
        raw: {
          id: 'apple-001',
          externalId: 'apple-001',
          source: 'apple-health',
          distanceMeters: 5000,
          distanceKm: 5,
          movingTimeSec: 1800,
          pace: '6:00/km'
        }
      }
    ]);
  });

  const { readStoredRuns } = await importFresh('../lib/run-store.js');
  const runs = await readStoredRuns();

  assert.equal(fetchMock.mock.callCount(), 1);
  assert.equal(runs.length, 1);
  assert.equal(runs[0].source, 'apple-health');
  assert.equal(runs[0].pace, '6:00/km');
});

test('Supabase run store upserts normalized runs through PostgREST', async () => {
  setEnv({
    RUN_STORE_BACKEND: 'supabase',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
    RUN_STORE_SUPABASE_TABLE: 'run_log_runs'
  });

  const calls = [];
  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    calls.push({ url: String(url), options });

    if (String(url).includes('/rest/v1/pghd_connections?')) {
      return Response.json([]);
    }

    if (options.method === 'POST' && String(url).includes('/rest/v1/pghd_activity_events?')) {
      assert.match(String(url), /\/rest\/v1\/pghd_activity_events\?on_conflict=source%2Cexternal_id$/);
      assert.equal(options.headers.Prefer, 'resolution=merge-duplicates,return=representation');
      const body = JSON.parse(options.body);
      assert.equal(body.source, 'strava');
      assert.equal(body.external_id, '123');
      assert.equal(body.activity_type, 'running');
      assert.equal(body.source_record_type, 'activity_event');
      assert.equal(body.duration_seconds, 1800);
      assert.equal(body.metrics.distance_meters, 5000);
      assert.equal(body.metrics.max_heartrate, 171);
      assert.equal(body.metrics.calories, 410);
      assert.equal(body.data_classification, 'PGHD');
      assert.equal(body.raw.externalId, '123');
      return Response.json([{ id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', ...body }]);
    }

    if (options.method === 'POST' && String(url).includes('/rest/v1/run_log_runs?')) {
      assert.match(String(url), /\/rest\/v1\/run_log_runs\?on_conflict=source%2Cexternal_id$/);
      assert.equal(options.headers.Prefer, 'resolution=merge-duplicates,return=representation');
      const body = JSON.parse(options.body);
      assert.equal(body.source, 'strava');
      assert.equal(body.external_id, '123');
      assert.equal(body.activity_type, 'running');
      assert.equal(body.source_record_type, 'activity_event');
      assert.equal(body.distance_meters, 5000);
      assert.equal(body.data_classification, 'PGHD');
      assert.equal(body.pghd_activity_event_id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      assert.equal(typeof body.raw_size_bytes, 'number');
      assert.equal(body.raw.externalId, '123');
      assert.equal(body.raw.dataClassification, 'PGHD');
      assert.equal(body.raw.pghdActivityEventId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      return Response.json([{ ...body, created_at: '2026-06-20T06:00:00Z' }]);
    }

    return Response.json([
      {
        source: 'strava',
        external_id: '123',
        start_date: '2026-06-20T06:00:00Z',
        distance_meters: 5000,
        moving_time_sec: 1800,
        raw: {
          id: 123,
          externalId: '123',
          source: 'strava',
          distanceMeters: 5000,
          movingTimeSec: 1800
        }
      }
    ]);
  });

  const { upsertStoredRun } = await importFresh('../lib/run-store.js');
  const result = await upsertStoredRun({
    id: 123,
    source: 'strava',
    startDate: '2026-06-20T06:00:00Z',
    distanceMeters: 5000,
    movingTimeSec: 1800,
    maxHeartrate: 171,
    calories: 410
  });

  assert.equal(fetchMock.mock.callCount(), 3);
  assert.match(calls[0].url, /\/rest\/v1\/pghd_activity_events\?/);
  assert.match(calls[1].url, /\/rest\/v1\/run_log_runs\?/);
  assert.equal(result.run.source, 'strava');
  assert.equal(result.run.pghdActivityEventId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  assert.equal(result.pghdActivityEvent.id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  assert.equal(result.count, 1);
});

test('Supabase run store resolves PGHD connection before upsert', async () => {
  setEnv({
    RUN_STORE_BACKEND: 'supabase',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });

  const subjectPersonId = '11111111-1111-4111-8111-111111111111';
  const connectionId = '22222222-2222-4222-8222-222222222222';
  const calls = [];
  mock.method(globalThis, 'fetch', async (url, options = {}) => {
    calls.push({ url: String(url), options });
    const href = String(url);

    if (href.includes('/rest/v1/pghd_connections?')) {
      assert.match(href, /provider=in\.%28apple-health%2Capple_health%29/);
      assert.match(href, /provider_user_id=in\.%28youngkwon%29/);
      return Response.json([
        {
          id: connectionId,
          person_id: subjectPersonId,
          provider: 'apple_health',
          provider_user_id: 'youngkwon',
          connection_status: 'connected'
        }
      ]);
    }

    if (options.method === 'POST' && href.includes('/rest/v1/pghd_activity_events?')) {
      const body = JSON.parse(options.body);
      assert.equal(body.subject_person_id, subjectPersonId);
      assert.equal(body.pghd_connection_id, connectionId);
      assert.equal(body.raw.connectionResolution.connectionResolved, true);
      return Response.json([{ id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', ...body }]);
    }

    if (options.method === 'POST' && href.includes('/rest/v1/run_log_runs?')) {
      const body = JSON.parse(options.body);
      assert.equal(body.subject_person_id, subjectPersonId);
      assert.equal(body.pghd_connection_id, connectionId);
      assert.equal(body.pghd_activity_event_id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      assert.equal(body.raw.connectionResolution.connectionResolved, true);
      return Response.json([{ ...body, created_at: '2026-06-20T06:00:00Z' }]);
    }

    return Response.json([]);
  });

  const { upsertStoredRun } = await importFresh('../lib/run-store.js');
  const result = await upsertStoredRun(
    {
      id: 'apple-001',
      source: 'apple-health',
      userId: 'youngkwon',
      startDate: '2026-06-20T06:00:00Z',
      distanceMeters: 5000,
      movingTimeSec: 1800
    },
    { skipCount: true }
  );

  assert.equal(result.run.subjectPersonId, subjectPersonId);
  assert.equal(result.run.pghdConnectionId, connectionId);
  assert.equal(result.run.pghdActivityEventId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  assert.equal(calls.length, 3);
});

test('Supabase run store keeps run_log_runs upsert when generic PGHD activity table is not applied', async () => {
  setEnv({
    RUN_STORE_BACKEND: 'supabase',
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key'
  });

  const calls = [];
  mock.method(globalThis, 'fetch', async (url, options = {}) => {
    calls.push({ url: String(url), options });
    const href = String(url);

    if (href.includes('/rest/v1/pghd_connections?')) return Response.json([]);

    if (href.includes('/rest/v1/pghd_activity_events?')) {
      return Response.json(
        { code: 'PGRST205', message: "Could not find the table 'public.pghd_activity_events'" },
        { status: 404 }
      );
    }

    if (options.method === 'POST' && href.includes('/rest/v1/run_log_runs?')) {
      const body = JSON.parse(options.body);
      assert.equal(body.source, 'strava');
      assert.equal(body.external_id, 'missing-generic');
      assert.equal(body.pghd_activity_event_id, undefined);
      return Response.json([{ ...body, created_at: '2026-06-20T06:00:00Z' }]);
    }

    return Response.json([]);
  });

  const { upsertStoredRun } = await importFresh('../lib/run-store.js');
  const result = await upsertStoredRun(
    {
      id: 'missing-generic',
      source: 'strava',
      startDate: '2026-06-20T06:00:00Z',
      distanceMeters: 5000,
      movingTimeSec: 1800
    },
    { skipCount: true }
  );

  assert.equal(result.run.externalId, 'missing-generic');
  assert.equal(result.pghdActivityEvent, undefined);
  assert.equal(calls.length, 2);
});

test('run store prunes dense telemetry from raw payloads', async () => {
  const { upsertStoredRun } = await importFresh('../lib/run-store.js');
  const path = await tempRunStorePath();
  const result = await upsertStoredRun({
    id: 'dense-001',
    source: 'apple-health',
    startDate: '2026-06-20T06:00:00Z',
    distanceMeters: 5000,
    movingTimeSec: 1800,
    routePoints: Array.from({ length: 150 }, (_, index) => ({
      lat: 37.5 + index / 10000,
      lng: 127.0 + index / 10000
    }))
  }, { path });

  assert.equal(result.run.routePoints, undefined);
  assert.equal(result.run.routePointCount, 150);
  assert.equal(result.run.telemetryRef.storage, 'external-required');
  assert.equal(result.run.dataClassification, 'PGHD');
  assert.equal(typeof result.run.rawSizeBytes, 'number');
});

test('run store rejects raw payloads over size budget', async () => {
  setEnv({ RUN_STORE_MAX_RAW_BYTES: '4096' });
  const { upsertStoredRun } = await importFresh('../lib/run-store.js');
  const path = await tempRunStorePath();

  await assert.rejects(
    () =>
      upsertStoredRun({
        id: 'large-001',
        source: 'file-import',
        startDate: '2026-06-20T06:00:00Z',
        distanceMeters: 5000,
        movingTimeSec: 1800,
        notes: 'x'.repeat(6000)
      }, { path }),
    /run raw payload exceeds RUN_STORE_MAX_RAW_BYTES/
  );
});
