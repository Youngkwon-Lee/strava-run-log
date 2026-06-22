#!/usr/bin/env node

import { readStoredRuns, upsertStoredRun } from '../lib/run-store.js';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`missing ${name}`);
  return value;
}

function makeRun(externalId) {
  return {
    id: externalId,
    externalId,
    source: 'smoke-test',
    provider: 'smoke-test',
    userId: 'local-smoke',
    name: 'Supabase run store smoke test',
    startDate: '2026-06-22T01:00:00.000Z',
    startedAt: '2026-06-22T01:00:00.000Z',
    endedAt: '2026-06-22T01:25:10.000Z',
    distanceMeters: 4020,
    distanceKm: 4.02,
    movingTimeSec: 1510,
    movingTime: '25:10',
    elapsedTimeSec: 1510,
    elapsedTime: '25:10',
    paceSecPerKm: 376,
    pace: '6:16/km',
    totalElevationGainMeters: 12.5,
    averageHeartrate: 142,
    averageCadence: 171,
    deviceName: 'Codex local smoke test',
    coaching: 'Smoke test row for Supabase run store verification.'
  };
}

async function main() {
  requireEnv('SUPABASE_URL');
  requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  process.env.RUN_STORE_BACKEND = process.env.RUN_STORE_BACKEND || 'supabase';
  process.env.RUN_STORE_SUPABASE_TABLE = process.env.RUN_STORE_SUPABASE_TABLE || 'run_log_runs';

  const externalId = process.argv[2] || `smoke_${new Date().toISOString().replace(/[-:.TZ]/g, '')}`;
  const upsert = await upsertStoredRun(makeRun(externalId), { skipCount: true });
  const runs = await readStoredRuns({ limit: 50 });
  const found = runs.find((run) => run.source === 'smoke-test' && run.externalId === externalId);

  if (!found) {
    throw new Error(`smoke row not found after upsert: ${externalId}`);
  }

  console.log(JSON.stringify({
    ok: true,
    table: process.env.RUN_STORE_SUPABASE_TABLE,
    externalId,
    upsertedSource: upsert.run.source,
    found: {
      source: found.source,
      distanceKm: found.distanceKm,
      pace: found.pace
    }
  }, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exit(1);
});
