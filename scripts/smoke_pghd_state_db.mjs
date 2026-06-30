#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { supabaseFetch } from '../lib/supabase-rest.js';

const DEFAULT_PHYSIO_APP_ENV_FILE = '/Users/youngkwon/projects/physio_app/.env.local';

function parseEnvFile(path) {
  const parsed = {};
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) continue;

    let value = match[2].trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    parsed[match[1]] = value;
  }
  return parsed;
}

function loadFallbackEnv() {
  if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) return;

  const candidates = [
    process.env.PGHD_SMOKE_ENV_FILE,
    DEFAULT_PHYSIO_APP_ENV_FILE
  ].filter(Boolean);

  for (const path of candidates) {
    if (!existsSync(path)) continue;

    const parsed = parseEnvFile(path);
    process.env.SUPABASE_URL = process.env.SUPABASE_URL || parsed.SUPABASE_URL || parsed.NEXT_PUBLIC_SUPABASE_URL || '';
    process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || parsed.SUPABASE_SERVICE_ROLE_KEY || '';
    if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) return;
  }
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`missing ${name}`);
  return value;
}

function qs(params) {
  return new URLSearchParams(params).toString();
}

export function makeSubjectId(stamp) {
  return `11111111-1111-4111-8111-${stamp.slice(-12)}`;
}

async function findSmokeSubjectPersonId() {
  const rows = await supabaseFetch(
    `/pghd_connections?${qs({
      select: 'person_id',
      person_id: 'not.is.null',
      order: 'updated_at.desc',
      limit: '1'
    })}`
  );
  const subjectPersonId = Array.isArray(rows) ? rows[0]?.person_id : null;
  if (!subjectPersonId) {
    throw new Error('no pghd_connections row exists to reuse a valid subject_person_id');
  }
  return subjectPersonId;
}

async function insertRun({ externalId, subjectPersonId }) {
  const params = new URLSearchParams({ on_conflict: 'source,external_id' });
  const rows = await supabaseFetch(`/run_log_runs?${params.toString()}`, {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify({
      source: 'state-db-smoke',
      external_id: externalId,
      user_id: 'state-db-smoke-user',
      name: 'PGHD state DB smoke run',
      start_date: '2026-06-22T12:10:00Z',
      activity_type: 'running',
      distance_meters: 5120,
      moving_time_sec: 1910,
      pace_sec_per_km: 373,
      average_heartrate: 148,
      max_heartrate: 171,
      average_cadence: 172,
      calories: 356,
      source_record_type: 'activity_event',
      subject_person_id: subjectPersonId,
      data_classification: 'PGHD',
      raw_size_bytes: 256,
      raw: {
        source: 'state-db-smoke',
        externalId,
        smoke: true
      }
    })
  });
  return Array.isArray(rows) ? rows[0] : null;
}

async function insertSnapshot({ externalId, subjectPersonId, windowStart }) {
  const rows = await supabaseFetch('/human_state_snapshots', {
    method: 'POST',
    headers: {
      Prefer: 'return=representation'
    },
    body: JSON.stringify({
      subject_person_id: subjectPersonId,
      state_type: 'training_load',
      value: 0.42,
      confidence: 0.65,
      window_start: windowStart,
      window_end: new Date(new Date(windowStart).getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      source: 'run_log_weekly_summaries',
      provider_source: 'state-db-smoke',
      metadata: {
        smoke: true,
        externalId
      }
    })
  });
  return Array.isArray(rows) ? rows[0] : null;
}

async function insertDuplicateSnapshot({ externalId, subjectPersonId, windowStart }) {
  try {
    await insertSnapshot({ externalId: `${externalId}_duplicate`, subjectPersonId, windowStart });
    return false;
  } catch (error) {
    if (/409|duplicate key value|human_state_snapshots_natural_key_idx/i.test(String(error?.message || error))) {
      return true;
    }
    throw error;
  }
}

async function insertInput({ snapshotId, runId }) {
  const rows = await supabaseFetch('/human_state_snapshot_inputs', {
    method: 'POST',
    headers: {
      Prefer: 'return=representation'
    },
    body: JSON.stringify({
      snapshot_id: snapshotId,
      run_log_run_id: runId,
      weight: 1
    })
  });
  return Array.isArray(rows) ? rows[0] : null;
}

async function cleanup({ externalId, subjectPersonId, runId, snapshotId }) {
  const errors = [];
  const steps = [
    async () =>
      supabaseFetch(
        `/human_state_snapshots?${qs({
          ...(snapshotId ? { id: `eq.${snapshotId}` } : {
            subject_person_id: `eq.${subjectPersonId}`,
            source: 'eq.run_log_weekly_summaries',
            provider_source: 'eq.state-db-smoke'
          })
        })}`,
        { method: 'DELETE' }
      ),
    async () =>
      supabaseFetch(
        `/run_log_runs?${qs({
          ...(runId ? { id: `eq.${runId}` } : {
            source: 'eq.state-db-smoke',
            external_id: `eq.${externalId}`
          })
        })}`,
        { method: 'DELETE' }
      )
  ];

  for (const step of steps) {
    try {
      await step();
    } catch (error) {
      if (/PGRST205|42P01|human_state_snapshots|human_state_snapshot_inputs|Could not find the table/i.test(String(error?.message || error))) {
        continue;
      }
      errors.push(error.message);
    }
  }
  return errors;
}

async function main() {
  loadFallbackEnv();
  requireEnv('SUPABASE_URL');
  requireEnv('SUPABASE_SERVICE_ROLE_KEY');

  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '');
  const context = {
    externalId: `state_db_smoke_${stamp}`,
    subjectPersonId: await findSmokeSubjectPersonId(),
    windowStart: new Date().toISOString()
  };

  try {
    const run = await insertRun(context);
    if (!run?.id || run.activity_type !== 'running' || run.source_record_type !== 'activity_event') {
      throw new Error('activity-event run row was not inserted with expected columns');
    }
    context.runId = run.id;

    const snapshot = await insertSnapshot(context);
    if (!snapshot?.id || snapshot.state_type !== 'training_load') {
      throw new Error('human_state_snapshots row was not inserted');
    }
    context.snapshotId = snapshot.id;

    const duplicatePrevented = await insertDuplicateSnapshot(context);
    if (!duplicatePrevented) {
      throw new Error('human_state_snapshots natural key did not prevent duplicate insert');
    }

    const input = await insertInput({ snapshotId: snapshot.id, runId: run.id });
    if (!input?.snapshot_id || !input?.run_log_run_id) {
      throw new Error('human_state_snapshot_inputs row was not inserted');
    }

    const cleanupErrors = await cleanup(context);
    if (cleanupErrors.length) throw new Error(`cleanup failed: ${cleanupErrors.join(' | ')}`);

    console.log(JSON.stringify({
      ok: true,
      externalId: context.externalId,
      subjectPersonId: context.subjectPersonId,
      runInserted: true,
      snapshotInserted: true,
      duplicatePrevented: true,
      inputLinkInserted: true
    }, null, 2));
  } catch (error) {
    const cleanupErrors = await cleanup(context);
    console.error(JSON.stringify({
      ok: false,
      error: error.message,
      cleanupErrors
    }, null, 2));
    process.exit(1);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
