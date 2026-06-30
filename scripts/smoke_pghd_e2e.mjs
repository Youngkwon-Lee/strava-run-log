#!/usr/bin/env node

import { createHmac, randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import appleHealthIngestHandler from '../api/apple-health/ingest.js';
import pghdConnectionsHandler from '../api/pghd/connections.js';
import preflightHandler from '../api/run-log/preflight.js';
import promoteToActivitySessionHandler from '../api/run-log/promote-to-activity-session.js';
import stateSnapshotsHandler from '../api/run-log/state-snapshots.js';
import timelineHandler from '../api/run-log/timeline.js';
import weeklySummariesHandler from '../api/run-log/weekly-summaries.js';
import { supabaseFetch } from '../lib/supabase-rest.js';

const DEFAULT_PHYSIO_APP_ENV_FILE = '/Users/youngkwon/projects/physio_app/.env.local';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`missing ${name}`);
  return value;
}

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
    process.env.APPLE_HEALTH_INGEST_TOKEN = process.env.APPLE_HEALTH_INGEST_TOKEN || parsed.APPLE_HEALTH_INGEST_TOKEN || '';
    if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) return;
  }
}

function ensureRuntimeEnv() {
  loadFallbackEnv();
  requireEnv('SUPABASE_URL');
  requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  process.env.RUN_STORE_BACKEND = process.env.RUN_STORE_BACKEND || 'supabase';
  process.env.RUN_STORE_SUPABASE_TABLE = process.env.RUN_STORE_SUPABASE_TABLE || 'run_log_runs';
  process.env.RUN_LOG_ADMIN_TOKEN = process.env.RUN_LOG_ADMIN_TOKEN || 'local-pghd-smoke-admin';
  process.env.APPLE_HEALTH_INGEST_TOKEN = process.env.APPLE_HEALTH_INGEST_TOKEN || 'local-pghd-smoke-apple';
}

function isTruthyEnv(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value || '').trim().toLowerCase());
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

export function buildPreflightEvidence(preflight) {
  const preflightStatuses = new Map((preflight?.checks || []).map((item) => [item.name, item.status]));
  const preflightChecks = Object.fromEntries(preflightStatuses);
  const preflightWarnings = (preflight?.checks || [])
    .filter((item) => item.status !== 'ok')
    .map((item) => ({
      name: item.name,
      status: item.status,
      message: item.message,
      operatorHints: item.operatorHints || []
    }));

  return {
    preflightStatus: preflight?.summary?.status,
    preflightChecks,
    preflightWarnings,
    preflightNextActions: preflight?.nextActions || []
  };
}

function qs(params) {
  const search = new URLSearchParams(params);
  return search.toString();
}

function isMissingTableError(error) {
  return /PGRST205|42P01|relation .+ does not exist|Could not find the table/i.test(
    String(error?.message || error || '')
  );
}

async function hasOrgClientContext(personId) {
  if (!personId) return false;
  try {
    const rows = await supabaseFetch(
      `/org_clients?${qs({
        select: 'id,person_id,organization_id,status',
        person_id: `eq.${personId}`,
        limit: '1'
      })}`
    );
    return Array.isArray(rows) && rows.length > 0;
  } catch (error) {
    if (isMissingTableError(error)) return false;
    throw error;
  }
}

async function firstConnectionWithOrgClientContext(rows) {
  for (const row of rows || []) {
    if (await hasOrgClientContext(row.person_id)) {
      return {
        ...row,
        hasOrgClientContext: true
      };
    }
  }
  return null;
}

async function findBootstrapMembership() {
  const explicitOrgId = String(process.env.PGHD_SMOKE_ORGANIZATION_ID || '').trim();
  const explicitProviderPersonId = String(process.env.PGHD_SMOKE_PROVIDER_PERSON_ID || '').trim();
  if (explicitOrgId && explicitProviderPersonId) {
    return {
      organization_id: explicitOrgId,
      person_id: explicitProviderPersonId,
      role: 'explicit'
    };
  }

  const rows = await supabaseFetch(
    `/organization_members?${qs({
      select: 'organization_id,person_id,role,status,updated_at',
      role: 'in.(owner,admin,provider,staff)',
      status: 'eq.active',
      deleted_at: 'is.null',
      order: 'updated_at.desc.nullslast',
      limit: '1'
    })}`
  );
  return Array.isArray(rows) ? rows[0] : null;
}

export function shouldBootstrapOrgClient(env = process.env) {
  return isTruthyEnv(env.PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT);
}

export function shouldMaterializeSmokeState(env = process.env) {
  return isTruthyEnv(env.PGHD_SMOKE_MATERIALIZE_STATE);
}

async function insertReturning(path, body) {
  const rows = await supabaseFetch(path, {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify(body)
  });
  const row = Array.isArray(rows) ? rows[0] : rows;
  if (!row?.id) throw new Error(`insert ${path} did not return an id`);
  return row;
}

async function createBootstrappedOrgClientContext(stamp) {
  const membership = await findBootstrapMembership();
  if (!membership?.organization_id || !membership?.person_id) {
    throw new Error('PGHD smoke bootstrap requires an active PhysioApp organization_members provider/staff row');
  }

  const personId = randomUUID();
  const providerUserId = `pghd-smoke-bootstrap-${stamp}`;
  const person = await insertReturning('/persons', {
    id: personId,
    first_name: 'PGHD',
    last_name: `Smoke-${stamp.slice(-6)}`,
    source_type: 'test',
    user_type: 'client',
    is_active: true,
    onboarding_status: 'completed',
    additional_info: {
      smoke: true,
      created_by: 'scripts/smoke_pghd_e2e.mjs',
      stamp
    }
  });

  const organizationMember = await insertReturning('/organization_members', {
    organization_id: membership.organization_id,
    person_id: person.id,
    role: 'client',
    status: 'active',
    joined_at: new Date().toISOString(),
    profile_metadata: {
      smoke: true,
      created_by: 'scripts/smoke_pghd_e2e.mjs',
      stamp
    }
  });

  const orgClient = await insertReturning('/org_clients', {
    organization_id: membership.organization_id,
    person_id: person.id,
    status: 'active',
    intake_date: new Date().toISOString().slice(0, 10),
    created_by: membership.person_id
  });

  const body = await callHandler(pghdConnectionsHandler, {
    method: 'POST',
    url: '/api/pghd/connections',
    headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
    query: {},
    body: {
      person_id: person.id,
      provider: 'apple-health',
      provider_user_id: providerUserId,
      connection_status: 'connected',
      metadata: {
        smoke: true,
        created_by: 'scripts/smoke_pghd_e2e.mjs',
        selected_for: 'bootstrapped_physio_org_client_context',
        organization_id: membership.organization_id,
        provider_person_id: membership.person_id,
        stamp
      }
    }
  });

  if (!body.connection?.id) throw new Error('bootstrapped apple-health pghd connection was not returned');
  return {
    connection: body.connection,
    providerUserId,
    created: true,
    hasOrgClientContext: true,
    selectionMode: 'bootstrapped_apple_health_org_client_context',
    bootstrapArtifacts: {
      personId: person.id,
      organizationMemberId: organizationMember.id,
      orgClientId: orgClient.id
    }
  };
}

async function findAppleHealthConnection() {
  const rows = await supabaseFetch(
    `/pghd_connections?${qs({
      select: 'id,person_id,provider,provider_user_id',
      provider: 'in.(apple-health,apple_health)',
      provider_user_id: 'not.is.null',
      order: 'updated_at.desc',
      limit: '20'
    })}`
  );
  const values = Array.isArray(rows) ? rows : [];
  return (await firstConnectionWithOrgClientContext(values)) || values[0] || null;
}

async function findAnyConnection() {
  const rows = await supabaseFetch(
    `/pghd_connections?${qs({
      select: 'id,person_id,provider,provider_user_id',
      person_id: 'not.is.null',
      order: 'updated_at.desc',
      limit: '20'
    })}`
  );
  const values = Array.isArray(rows) ? rows : [];
  return (await firstConnectionWithOrgClientContext(values)) || values[0] || null;
}

async function ensureAppleHealthConnection(stamp) {
  const existing = await findAppleHealthConnection();
  if (existing?.person_id && existing?.provider_user_id && existing.hasOrgClientContext) {
    return {
      connection: existing,
      providerUserId: existing.provider_user_id,
      created: false,
      hasOrgClientContext: true,
      selectionMode: 'existing_apple_health_with_org_client_context'
    };
  }

  const base = await findAnyConnection();
  if (base?.person_id && base.hasOrgClientContext) {
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
        connection_status: 'connected',
        metadata: {
          smoke: true,
          created_by: 'scripts/smoke_pghd_e2e.mjs',
          selected_for: 'physio_org_client_context'
        }
      }
    });

    if (!body.connection?.id) throw new Error('temporary apple-health pghd connection was not returned');
    return {
      connection: body.connection,
      providerUserId,
      created: true,
      hasOrgClientContext: true,
      selectionMode: 'temporary_apple_health_from_org_client_context'
    };
  }

  if (shouldBootstrapOrgClient()) {
    return createBootstrappedOrgClientContext(stamp);
  }

  if (existing?.person_id && existing?.provider_user_id) {
    return {
      connection: existing,
      providerUserId: existing.provider_user_id,
      created: false,
      hasOrgClientContext: false,
      selectionMode: 'existing_apple_health_without_org_client_context'
    };
  }

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
      connection_status: 'connected',
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
    created: true,
    hasOrgClientContext: Boolean(base.hasOrgClientContext),
    selectionMode: base.hasOrgClientContext
      ? 'temporary_apple_health_from_org_client_context'
      : 'temporary_apple_health_without_org_client_context'
  };
}

export function assertOrgClientContextSelection(mapped, env = process.env) {
  if (!isTruthyEnv(env.PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT)) return;
  if (mapped?.hasOrgClientContext) return;

  throw new Error(
    'PGHD smoke requires an org-client subject, but no reusable PGHD connection with org_clients context was found'
  );
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

async function cleanup({ externalId, activitySessionId, temporaryConnectionId, bootstrapArtifacts, materializedStateSnapshotIds }) {
  const errors = [];
  const runFilter = qs({ source: 'eq.apple-health', external_id: `eq.${externalId}` });
  const orgClientId = bootstrapArtifacts?.orgClientId;
  const organizationMemberId = bootstrapArtifacts?.organizationMemberId;
  const personId = bootstrapArtifacts?.personId;
  const stateSnapshotIds = materializedStateSnapshotIds || [];

  for (const step of [
    async () => stateSnapshotIds.length && supabaseFetch(`/human_state_snapshots?${qs({ id: `in.(${stateSnapshotIds.join(',')})` })}`, { method: 'DELETE' }),
    async () => supabaseFetch(`/run_log_runs?${runFilter}`, { method: 'DELETE' }),
    async () => activitySessionId && supabaseFetch(`/activity_sessions?${qs({ id: `eq.${activitySessionId}` })}`, { method: 'DELETE' }),
    async () => temporaryConnectionId && supabaseFetch(`/pghd_connections?${qs({ id: `eq.${temporaryConnectionId}` })}`, { method: 'DELETE' }),
    async () => orgClientId && supabaseFetch(`/org_clients?${qs({ id: `eq.${orgClientId}` })}`, { method: 'DELETE' }),
    async () => organizationMemberId && supabaseFetch(`/organization_members?${qs({ id: `eq.${organizationMemberId}` })}`, { method: 'DELETE' }),
    async () => personId && supabaseFetch(`/persons?${qs({ id: `eq.${personId}` })}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        is_active: false,
        anonymized_at: new Date().toISOString(),
        additional_info: {
          smoke: true,
          cleanup: 'pghd_smoke_tombstone',
          cleaned_at: new Date().toISOString()
        }
      })
    })
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
    temporaryConnectionId: null,
    bootstrapArtifacts: null,
    materializedStateSnapshotIds: []
  };

  try {
    ensureRuntimeEnv();

    const mapped = await ensureAppleHealthConnection(stamp);
    assertOrgClientContextSelection(mapped);
    if (mapped.created) context.temporaryConnectionId = mapped.connection.id;
    if (mapped.bootstrapArtifacts) context.bootstrapArtifacts = mapped.bootstrapArtifacts;

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

    let materializedState = null;
    if (shouldMaterializeSmokeState()) {
      if (!mapped.bootstrapArtifacts) {
        throw new Error('PGHD_SMOKE_MATERIALIZE_STATE requires PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT so existing client state is not replaced');
      }
      materializedState = await callHandler(stateSnapshotsHandler, {
        method: 'POST',
        url: '/api/run-log/state-snapshots',
        headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
        query: {},
        body: {
          subject_person_id: storedRun.subject_person_id,
          source: 'apple-health',
          derive: 'weekly',
          limit: '12'
        }
      });
      context.materializedStateSnapshotIds = (materializedState.snapshots || [])
        .map((snapshot) => snapshot.id)
        .filter(Boolean);
      if (!context.materializedStateSnapshotIds.length) {
        throw new Error('state materialization did not persist any snapshots');
      }
    }

    const preflight = await callHandler(preflightHandler, {
      method: 'GET',
      url: '/api/run-log/preflight',
      headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
      query: {
        subject_person_id: storedRun.subject_person_id,
        source: 'apple-health',
        limit: '5'
      },
      body: {}
    });
    const preflightEvidence = buildPreflightEvidence(preflight);
    const preflightStatuses = new Map(Object.entries(preflightEvidence.preflightChecks));
    if (!['ok', 'warning'].includes(preflightStatuses.get('physio_person_context'))) {
      throw new Error('preflight physio_person_context was not ok or warning');
    }
    for (const name of ['run_store_backend', 'connection_mapping', 'activity_ingest', 'weekly_summary']) {
      if (preflightStatuses.get(name) !== 'ok') {
        throw new Error(`preflight ${name} was not ok`);
      }
    }
    if (!['ok', 'warning'].includes(preflightStatuses.get('state_materialization'))) {
      throw new Error('preflight state_materialization was not ok or warning');
    }

    const stateSignals = await callHandler(stateSnapshotsHandler, {
      method: 'GET',
      url: '/api/run-log/state-snapshots',
      headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
      query: {
        subject_person_id: storedRun.subject_person_id,
        source: 'apple-health',
        derive: 'weekly',
        limit: '12'
      },
      body: {}
    });
    const stateTypes = new Set((stateSignals.snapshots || []).map((snapshot) => snapshot.stateType));
    if (!stateTypes.has('training_load') || !stateTypes.has('adherence')) {
      throw new Error('derived state signals did not include training_load and adherence');
    }

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

    const timeline = await callHandler(timelineHandler, {
      method: 'GET',
      url: '/api/run-log/timeline',
      headers: { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` },
      query: {
        subject_person_id: storedRun.subject_person_id,
        source: 'apple-health',
        limit: '10'
      },
      body: {}
    });
    const timelineFound = timeline.timeline.some((item) => item.externalId === payload.external_run_id && item.promoted);
    if (!timelineFound) throw new Error('timeline did not include the promoted smoke Apple Health run');

    const cleanupErrors = await cleanup(context);
    if (cleanupErrors.length) throw new Error(`cleanup failed: ${cleanupErrors.join(' | ')}`);

    console.log(JSON.stringify({
      ok: true,
      steps: [
        'pghd connection resolved',
        'apple-health ingest stored run',
        'weekly summary found run',
        ...(materializedState ? ['persisted state snapshots materialized'] : []),
        'pghd preflight checked readiness',
        'derived state signals calculated',
        'activity session promoted',
        'client timeline found promoted run',
        'smoke rows cleaned up'
      ],
      evidence: {
        externalId: payload.external_run_id,
        reusedExistingConnection: !mapped.created,
        connectionSelectionMode: mapped.selectionMode,
        selectedOrgClientContext: mapped.hasOrgClientContext,
        bootstrappedOrgClientContext: Boolean(mapped.bootstrapArtifacts),
        materializedStateSnapshotCount: materializedState?.count || 0,
        subjectPersonId: maskId(storedRun.subject_person_id),
        pghdConnectionId: maskId(storedRun.pghd_connection_id),
        activitySessionId: maskId(context.activitySessionId),
        ...preflightEvidence,
        stateSignalCount: stateSignals.count,
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

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
