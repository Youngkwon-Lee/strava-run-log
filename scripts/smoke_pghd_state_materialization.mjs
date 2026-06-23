#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import stateSnapshotsHandler from '../api/run-log/state-snapshots.js';
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
    process.env.RUN_LOG_ADMIN_TOKEN = process.env.RUN_LOG_ADMIN_TOKEN || parsed.RUN_LOG_ADMIN_TOKEN || '';
    if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) return;
  }
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`missing ${name}`);
  return value;
}

function createResponse() {
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
  const res = createResponse();
  await handler(req, res);
  if (res.statusCode >= 400) {
    throw new Error(`${req.method} ${req.url || req.path || 'handler'} failed: ${res.statusCode} ${JSON.stringify(res.body)}`);
  }
  return res.body;
}

function qs(params) {
  return new URLSearchParams(params).toString();
}

export function makeSubjectId(stamp) {
  return `11111111-1111-4111-8111-${stamp.slice(-12)}`;
}

export function assertSnapshotsHaveInputs(snapshots, label) {
  const missing = (snapshots || []).filter((snapshot) => !Array.isArray(snapshot.inputs) || !snapshot.inputs.length);
  if (missing.length) {
    throw new Error(`${label} snapshots missing traceability inputs: ${missing.map((snapshot) => snapshot.stateType || snapshot.id).join(', ')}`);
  }
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

async function insertSmokeRun({ externalId, subjectPersonId }) {
  const row = {
    source: 'state-smoke',
    external_id: externalId,
    user_id: `state-smoke-user-${externalId}`,
    subject_person_id: subjectPersonId,
    name: 'State materialization smoke run',
    start_date: '2026-06-22T01:00:00Z',
    start_date_local: '2026-06-22T10:00:00+09:00',
    activity_type: 'running',
    ended_at: '2026-06-22T01:30:00Z',
    distance_meters: 5000,
    moving_time_sec: 1800,
    pace_sec_per_km: 360,
    average_heartrate: 142,
    max_heartrate: 168,
    average_cadence: 171,
    calories: 340,
    source_record_type: 'activity_event',
    data_classification: 'PGHD',
    raw: {
      id: externalId,
      externalId,
      source: 'state-smoke',
      activityType: 'running',
      distanceMeters: 5000,
      movingTimeSec: 1800,
      smoke: true
    }
  };

  const params = new URLSearchParams({ on_conflict: 'source,external_id' });
  const rows = await supabaseFetch(`/run_log_runs?${params.toString()}`, {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify(row)
  });
  return Array.isArray(rows) ? rows[0] : null;
}

async function cleanup({ externalId, subjectPersonId }) {
  const errors = [];
  for (const step of [
    async () =>
      supabaseFetch(
        `/human_state_snapshots?${qs({
          subject_person_id: `eq.${subjectPersonId}`,
          source: 'eq.run_log_weekly_summaries',
          provider_source: 'eq.state-smoke'
        })}`,
        { method: 'DELETE' }
      ),
    async () =>
      supabaseFetch(
        `/run_log_runs?${qs({
          source: 'eq.state-smoke',
          external_id: `eq.${externalId}`
        })}`,
        { method: 'DELETE' }
      )
  ]) {
    try {
      await step();
    } catch (error) {
      if (/PGRST205|42P01|human_state_snapshots|Could not find the table/i.test(String(error?.message || error))) {
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
  process.env.RUN_LOG_ADMIN_TOKEN = process.env.RUN_LOG_ADMIN_TOKEN || 'local-pghd-smoke-admin';

  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '');
  const externalId = `state_smoke_${stamp}`;
  const subjectPersonId = await findSmokeSubjectPersonId();
  const context = { externalId, subjectPersonId };

  try {
    const run = await insertSmokeRun(context);
    if (!run?.external_id) throw new Error('state smoke run was not inserted');
    if (run.activity_type !== 'running' || run.source_record_type !== 'activity_event') {
      throw new Error('state smoke run was not inserted as an activity_event');
    }

    const materialized = await callHandler(stateSnapshotsHandler, {
      method: 'POST',
      url: '/api/run-log/state-snapshots',
      headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
      query: {},
      body: {
        subject_person_id: subjectPersonId,
        source: 'state-smoke',
        derive: 'weekly',
        limit: 12
      }
    });

    const stateTypes = new Set((materialized.snapshots || []).map((snapshot) => snapshot.stateType));
    if (!stateTypes.has('training_load') || !stateTypes.has('adherence') || !stateTypes.has('fatigue')) {
      throw new Error('materialized state snapshots did not include training_load, adherence, and fatigue');
    }
    assertSnapshotsHaveInputs(materialized.snapshots, 'materialized');

    const readBack = await callHandler(stateSnapshotsHandler, {
      method: 'GET',
      url: '/api/run-log/state-snapshots',
      headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
      query: {
        subject_person_id: subjectPersonId,
        limit: '12'
      },
      body: {}
    });
    if (Number(readBack.count || 0) < 3) throw new Error('persisted state snapshots were not readable after materialization');
    assertSnapshotsHaveInputs(readBack.snapshots, 'read-back');

    const cleanupErrors = await cleanup(context);
    if (cleanupErrors.length) throw new Error(`cleanup failed: ${cleanupErrors.join(' | ')}`);

    console.log(JSON.stringify({
      ok: true,
      externalId,
      subjectPersonId,
      materializedCount: materialized.count,
      readBackCount: readBack.count,
      inputLinkCount: (readBack.snapshots || []).reduce((sum, snapshot) => sum + (snapshot.inputs || []).length, 0)
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
