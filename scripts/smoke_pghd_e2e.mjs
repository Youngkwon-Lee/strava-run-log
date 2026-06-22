#!/usr/bin/env node

import { createHmac } from 'node:crypto';
import appleHealthIngestHandler from '../api/apple-health/ingest.js';
import pghdConnectionsHandler from '../api/pghd/connections.js';
import promoteToActivitySessionHandler from '../api/run-log/promote-to-activity-session.js';
import weeklySummariesHandler from '../api/run-log/weekly-summaries.js';
import { supabaseFetch } from '../lib/supabase-rest.js';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`missing ${name}`);
  return value;
}

function ensureRuntimeEnv() {
  requireEnv('SUPABASE_URL');
  requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  process.env.RUN_STORE_BACKEND = process.env.RUN_STORE_BACKEND || 'supabase';
  process.env.RUN_STORE_SUPABASE_TABLE = process.env.RUN_STORE_SUPABASE_TABLE || 'run_log_runs';
  process.env.RUN_LOG_ADMIN_TOKEN = process.env.RUN_LOG_ADMIN_TOKEN || 'local-pghd-smoke-admin';
  process.env.APPLE_HEALTH_INGEST_TOKEN = process.env.APPLE_HEALTH_INGEST_TOKEN || 'local-pghd-smoke-apple';
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

function maskId(value) {
  const text = String(value || '');
  if (text.length <= 12) return text ? '***' : null;
  return `${text.slice(0, 8)}...${text.slice(-4)}`;
}

function qs(params) {
  const search = new URLSearchParams(params);
  return search.toString();
}

async function findAppleHealthConnection() {
  const rows = await supabaseFetch(
    `/pghd_connections?${qs({
      select: 'id,person_id,provider,provider_user_id',
      provider: 'in.(apple-health,apple_health)',
      provider_user_id: 'not.is.null',
      order: 'updated_at.desc',
      limit: '1'
    })}`
  );
  return Array.isArray(rows) ? rows[0] : null;
}

async function findAnyConnection() {
  const rows = await supabaseFetch(
    `/pghd_connections?${qs({
      select: 'id,person_id,provider,provider_user_id',
      person_id: 'not.is.null',
      order: 'updated_at.desc',
      limit: '1'
    })}`
  );
  return Array.isArray(rows) ? rows[0] : null;
}

async function ensureAppleHealthConnection(stamp) {
  const existing = await findAppleHealthConnection();
  if (existing?.person_id && existing?.provider_user_id) {
    return {
      connection: existing,
      providerUserId: existing.provider_user_id,
      created: false
    };
  }

  const base = await findAnyConnection();
  if (!base?.person_id) {
    throw new Error('no pghd_connections row exists to reuse a valid person_id');
  }

  const providerUserId = `pghd-smoke-${stamp}`;
  const body = await callHandler(pghdConnectionsHandler, {
    method: 'POST',
    url: '/api/pghd/connections',
    headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
    query: {},
    body: {
      person_id: base.person_id,
      provider: 'apple-health',
      provider_user_id: providerUserId,
      connection_status: 'active',
      metadata: {
        smoke: true,
        created_by: 'scripts/smoke_pghd_e2e.mjs'
      }
    }
  });

  if (!body.connection?.id) throw new Error('temporary apple-health pghd connection was not returned');
  return {
    connection: body.connection,
    providerUserId,
    created: true
  };
}

function makeApplePayload(stamp, providerUserId) {
  const startedAt = '2026-06-22T21:10:00.000+09:00';
  const endedAt = '2026-06-22T21:42:30.000+09:00';
  return {
    external_run_id: `apple_health_pghd_smoke_${stamp}`,
    user_id: providerUserId,
    started_at: startedAt,
    ended_at: endedAt,
    distance_m: 5120,
    moving_time_s: 1910,
    elapsed_time_s: 1950,
    elevation_gain_m: 28,
    avg_hr: 148,
    max_hr: 171,
    cadence_avg: 172,
    calories: 356,
    device_source: 'Codex smoke Apple Watch',
    source_app: 'Apple Health',
    send_to_discord: false,
    splits: [
      { km: 1, moving_time_s: 371, avg_hr: 138 },
      { km: 2, moving_time_s: 374, avg_hr: 146 },
      { km: 3, moving_time_s: 376, avg_hr: 151 },
      { km: 4, moving_time_s: 380, avg_hr: 153 },
      { km: 5, moving_time_s: 309, avg_hr: 157 }
    ]
  };
}

function appleHeaders(bodyText) {
  const headers = { authorization: `Bearer ${process.env.APPLE_HEALTH_INGEST_TOKEN}` };
  if (process.env.APPLE_HEALTH_SIGNING_SECRET) {
    headers['x-signature'] = createHmac('sha256', process.env.APPLE_HEALTH_SIGNING_SECRET).update(bodyText).digest('hex');
  }
  return headers;
}

async function fetchStoredRun(externalId) {
  const rows = await supabaseFetch(
    `/run_log_runs?${qs({
      select: 'source,external_id,user_id,subject_person_id,pghd_connection_id,activity_session_id,distance_meters,moving_time_sec',
      source: 'eq.apple-health',
      external_id: `eq.${externalId}`,
      limit: '1'
    })}`
  );
  return Array.isArray(rows) ? rows[0] : null;
}

async function cleanup({ externalId, activitySessionId, temporaryConnectionId }) {
  const errors = [];
  const runFilter = qs({ source: 'eq.apple-health', external_id: `eq.${externalId}` });

  for (const step of [
    async () => supabaseFetch(`/run_log_runs?${runFilter}`, { method: 'DELETE' }),
    async () => activitySessionId && supabaseFetch(`/activity_sessions?${qs({ id: `eq.${activitySessionId}` })}`, { method: 'DELETE' }),
    async () => temporaryConnectionId && supabaseFetch(`/pghd_connections?${qs({ id: `eq.${temporaryConnectionId}` })}`, { method: 'DELETE' })
  ]) {
    try {
      await step();
    } catch (error) {
      errors.push(error.message);
    }
  }

  return errors;
}

async function main() {
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '');
  const context = {
    externalId: null,
    activitySessionId: null,
    temporaryConnectionId: null
  };

  try {
    ensureRuntimeEnv();

    const mapped = await ensureAppleHealthConnection(stamp);
    if (mapped.created) context.temporaryConnectionId = mapped.connection.id;

    const payload = makeApplePayload(stamp, mapped.providerUserId);
    context.externalId = payload.external_run_id;
    const rawBody = JSON.stringify(payload);

    const ingest = await callHandler(appleHealthIngestHandler, {
      method: 'POST',
      url: '/api/apple-health/ingest',
      headers: appleHeaders(rawBody),
      query: {},
      rawBody,
      body: payload
    });

    const storedRun = await fetchStoredRun(payload.external_run_id);
    if (!storedRun?.subject_person_id || !storedRun?.pghd_connection_id) {
      throw new Error('stored run did not resolve subject_person_id and pghd_connection_id');
    }

    const summaries = await callHandler(weeklySummariesHandler, {
      method: 'GET',
      url: '/api/run-log/weekly-summaries',
      headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
      query: {
        source: 'apple-health',
        user_id: mapped.providerUserId,
        limit: '5'
      },
      body: {}
    });
    const summaryFound = summaries.summaries.some((row) => row.user_id === mapped.providerUserId && Number(row.run_count) >= 1);
    if (!summaryFound) throw new Error('weekly summary did not include the smoke Apple Health run');

    const promoted = await callHandler(promoteToActivitySessionHandler, {
      method: 'POST',
      url: '/api/run-log/promote-to-activity-session',
      headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
      query: {},
      body: {
        source: 'apple-health',
        external_id: payload.external_run_id,
        activity_type: 'competition',
        notes: 'PGHD E2E smoke test'
      }
    });
    context.activitySessionId = promoted.activitySessionId;
    if (!context.activitySessionId) throw new Error('promotion did not return activitySessionId');

    const cleanupErrors = await cleanup(context);
    if (cleanupErrors.length) throw new Error(`cleanup failed: ${cleanupErrors.join(' | ')}`);

    console.log(JSON.stringify({
      ok: true,
      steps: [
        'pghd connection resolved',
        'apple-health ingest stored run',
        'weekly summary found run',
        'activity session promoted',
        'smoke rows cleaned up'
      ],
      evidence: {
        externalId: payload.external_run_id,
        reusedExistingConnection: !mapped.created,
        subjectPersonId: maskId(storedRun.subject_person_id),
        pghdConnectionId: maskId(storedRun.pghd_connection_id),
        activitySessionId: maskId(context.activitySessionId),
        distanceKm: ingest.summary.distanceKm,
        pace: ingest.summary.pace
      }
    }, null, 2));
  } catch (error) {
    const cleanupErrors = context.externalId ? await cleanup(context) : [];
    console.error(JSON.stringify({
      ok: false,
      error: error.message,
      cleanupErrors
    }, null, 2));
    process.exit(1);
  }
}

main();
