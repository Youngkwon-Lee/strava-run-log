#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import encounterInsightsHandler from '../api/run-log/encounter-insights.js';
import preflightHandler from '../api/run-log/preflight.js';
import stateSnapshotsHandler from '../api/run-log/state-snapshots.js';
import timelineHandler from '../api/run-log/timeline.js';
import pghdConnectionsHandler from '../api/pghd/connections.js';
import { upsertStoredRun } from '../lib/run-store.js';
import { supabaseFetch } from '../lib/supabase-rest.js';

const DEFAULT_PHYSIO_APP_ENV_FILE = '/Users/youngkwon/projects/physio_app/.env.local';
const DEMO_SUBJECT_PERSON_ID = '22222222-2222-4222-8222-222222222222';
const DEMO_PROVIDER_USER_ID = 'pghd-demo-client-apple-watch';
const DEMO_SOURCE = 'apple-health';
const DEMO_BASE_URL = 'https://strava-run-log.vercel.app';

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
    process.env.PGHD_DEMO_ENV_FILE,
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

function ensureRuntimeEnv() {
  loadFallbackEnv();
  requireEnv('SUPABASE_URL');
  requireEnv('SUPABASE_SERVICE_ROLE_KEY');
  process.env.RUN_STORE_BACKEND = process.env.RUN_STORE_BACKEND || 'supabase';
  process.env.RUN_STORE_SUPABASE_TABLE = process.env.RUN_STORE_SUPABASE_TABLE || 'run_log_runs';
  process.env.RUN_LOG_ADMIN_TOKEN = process.env.RUN_LOG_ADMIN_TOKEN || 'local-pghd-demo-admin';
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

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function adminHeaders() {
  return { authorization: `Bearer ${process.env.RUN_LOG_ADMIN_TOKEN}` };
}

async function findBootstrapMembership() {
  const explicitOrgId = String(process.env.PGHD_DEMO_ORGANIZATION_ID || process.env.PGHD_SMOKE_ORGANIZATION_ID || '').trim();
  const explicitProviderPersonId = String(process.env.PGHD_DEMO_PROVIDER_PERSON_ID || process.env.PGHD_SMOKE_PROVIDER_PERSON_ID || '').trim();
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

async function upsertPerson() {
  const rows = await supabaseFetch('/persons?on_conflict=id', {
    method: 'POST',
    headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
    body: JSON.stringify({
      id: DEMO_SUBJECT_PERSON_ID,
      first_name: 'PGHD',
      last_name: 'Demo Client',
      source_type: 'test',
      user_type: 'client',
      is_active: true,
      onboarding_status: 'completed',
      additional_info: {
        demo: true,
        pghd_demo_client: true,
        created_by: 'scripts/seed_pghd_demo_client.mjs',
        persistent: true
      }
    })
  });
  const row = Array.isArray(rows) ? rows[0] : rows;
  if (!row?.id) throw new Error('demo person upsert did not return an id');
  return row;
}

async function ensureOrganizationMember({ organizationId }) {
  const existing = await supabaseFetch(
    `/organization_members?${qs({
      select: 'id,organization_id,person_id,role,status',
      organization_id: `eq.${organizationId}`,
      person_id: `eq.${DEMO_SUBJECT_PERSON_ID}`,
      role: 'eq.client',
      limit: '1'
    })}`
  );
  if (existing?.[0]?.id) return existing[0];

  const rows = await supabaseFetch('/organization_members', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      organization_id: organizationId,
      person_id: DEMO_SUBJECT_PERSON_ID,
      role: 'client',
      status: 'active',
      joined_at: new Date().toISOString(),
      profile_metadata: {
        demo: true,
        pghd_demo_client: true,
        created_by: 'scripts/seed_pghd_demo_client.mjs'
      }
    })
  });
  const row = Array.isArray(rows) ? rows[0] : rows;
  if (!row?.id) throw new Error('demo organization_members insert did not return an id');
  return row;
}

async function ensureOrgClient({ organizationId, providerPersonId }) {
  const existing = await supabaseFetch(
    `/org_clients?${qs({
      select: 'id,organization_id,person_id,status',
      organization_id: `eq.${organizationId}`,
      person_id: `eq.${DEMO_SUBJECT_PERSON_ID}`,
      limit: '1'
    })}`
  );
  if (existing?.[0]?.id) return existing[0];

  const rows = await supabaseFetch('/org_clients', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      organization_id: organizationId,
      person_id: DEMO_SUBJECT_PERSON_ID,
      status: 'active',
      intake_date: '2026-06-01',
      created_by: providerPersonId
    })
  });
  const row = Array.isArray(rows) ? rows[0] : rows;
  if (!row?.id) throw new Error('demo org_clients insert did not return an id');
  return row;
}

async function ensureOrgClientProfile({ organizationId }) {
  const rows = await supabaseFetch('/org_client_profile?on_conflict=organization_id,person_id', {
    method: 'POST',
    headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
    body: JSON.stringify({
      organization_id: organizationId,
      person_id: DEMO_SUBJECT_PERSON_ID,
      client_type: 'patient',
      service_line: 'sports',
      care_setting: 'hybrid',
      primary_diagnosis: 'PGHD demo running load review',
      goals_summary: 'Review wearable activity evidence before progressing the plan.',
      payer_type: 'self_pay',
      metadata: {
        demo: true,
        pghd_demo_client: true,
        created_by: 'scripts/seed_pghd_demo_client.mjs',
        persistent: true
      }
    })
  });
  const row = Array.isArray(rows) ? rows[0] : rows;
  if (!row?.id) throw new Error('demo org_client_profile upsert did not return an id');
  return row;
}

async function ensureConnection({ organizationId, providerPersonId }) {
  const body = await callHandler(pghdConnectionsHandler, {
    method: 'POST',
    url: '/api/pghd/connections',
    headers: adminHeaders(),
    query: {},
    body: {
      person_id: DEMO_SUBJECT_PERSON_ID,
      provider: DEMO_SOURCE,
      provider_user_id: DEMO_PROVIDER_USER_ID,
      connection_status: 'connected',
      metadata: {
        demo: true,
        pghd_demo_client: true,
        persistent: true,
        created_by: 'scripts/seed_pghd_demo_client.mjs',
        organization_id: organizationId,
        provider_person_id: providerPersonId
      }
    }
  });
  if (!body.connection?.id) throw new Error('demo pghd connection upsert did not return an id');
  return body.connection;
}

function demoRuns({ organizationId, orgClientProfileId, pghdConnectionId }) {
  const base = {
    source: DEMO_SOURCE,
    provider: DEMO_SOURCE,
    userId: DEMO_PROVIDER_USER_ID,
    subjectPersonId: DEMO_SUBJECT_PERSON_ID,
    organizationId,
    orgClientProfileId,
    pghdConnectionId,
    activityType: 'running',
    sourceRecordType: 'activity_event',
    dataClassification: 'PGHD',
    deviceName: 'Codex Demo Apple Watch',
    sourceApp: 'Apple Health',
    demo: true
  };

  return [
    ['pghd_demo_20260615_1', '2026-06-15T21:00:00+09:00', 5000, 1830, 366, 142, 166, 170, 345],
    ['pghd_demo_20260618_1', '2026-06-18T07:10:00+09:00', 5200, 1910, 367, 145, 169, 171, 358],
    ['pghd_demo_20260622_1', '2026-06-22T21:10:00+09:00', 8200, 2980, 363, 151, 176, 172, 590],
    ['pghd_demo_20260624_1', '2026-06-24T07:25:00+09:00', 7600, 2800, 368, 149, 173, 171, 540],
    ['pghd_demo_20260626_1', '2026-06-26T20:20:00+09:00', 9100, 3360, 369, 154, 181, 170, 655],
    ['pghd_demo_20260628_1', '2026-06-28T08:35:00+09:00', 6800, 2510, 369, 147, 170, 172, 490],
    ['pghd_demo_20260629_1', '2026-06-29T19:30:00+09:00', 8600, 3190, 371, 156, 182, 171, 625]
  ].map(([externalId, startedAt, distanceMeters, movingTimeSec, paceSecPerKm, averageHeartrate, maxHeartrate, averageCadence, calories]) => {
    const endedAt = new Date(Date.parse(startedAt) + movingTimeSec * 1000).toISOString();
    const distanceKm = Number((distanceMeters / 1000).toFixed(2));
    const run = compactObject({
      ...base,
      id: externalId,
      externalId,
      externalRunId: externalId,
      name: `PGHD Demo Run ${startedAt.slice(5, 10)}`,
      startDate: startedAt,
      startedAt,
      endedAt,
      distanceMeters,
      distanceKm,
      movingTimeSec,
      elapsedTimeSec: movingTimeSec + 90,
      paceSecPerKm,
      pace: `${Math.floor(paceSecPerKm / 60)}:${String(Math.round(paceSecPerKm % 60)).padStart(2, '0')}/km`,
      averageHeartrate,
      maxHeartrate,
      averageCadence,
      calories,
      raw: {
        demo: true,
        pghdDemoClient: true,
        externalId
      }
    });
    return run;
  });
}

async function upsertDemoRuns(context) {
  const rows = [];
  for (const run of demoRuns(context)) {
    const result = await upsertStoredRun(run, { skipCount: true, resolveConnection: false });
    rows.push(result.run);
  }
  return rows;
}

async function materializeState(context) {
  return callHandler(stateSnapshotsHandler, {
    method: 'POST',
    url: '/api/run-log/state-snapshots',
    headers: adminHeaders(),
    query: {},
    body: {
      subject_person_id: DEMO_SUBJECT_PERSON_ID,
      organization_id: context.organizationId,
      org_client_profile_id: context.orgClientProfileId,
      source: DEMO_SOURCE,
      derive: 'weekly',
      limit: 12
    }
  });
}

async function readState(context) {
  return callHandler(stateSnapshotsHandler, {
    method: 'GET',
    url: '/api/run-log/state-snapshots',
    headers: adminHeaders(),
    query: {
      subject_person_id: DEMO_SUBJECT_PERSON_ID,
      organization_id: context.organizationId,
      org_client_profile_id: context.orgClientProfileId,
      source: DEMO_SOURCE,
      limit: '12'
    },
    body: {}
  });
}

async function readPreflight(context) {
  return callHandler(preflightHandler, {
    method: 'GET',
    url: '/api/run-log/preflight',
    headers: adminHeaders(),
    query: {
      subject_person_id: DEMO_SUBJECT_PERSON_ID,
      organization_id: context.organizationId,
      source: DEMO_SOURCE,
      limit: '5'
    },
    body: {}
  });
}

async function readInsights(context) {
  return callHandler(encounterInsightsHandler, {
    method: 'GET',
    url: '/api/run-log/encounter-insights',
    headers: adminHeaders(),
    query: {
      subject_person_id: DEMO_SUBJECT_PERSON_ID,
      organization_id: context.organizationId,
      org_client_profile_id: context.orgClientProfileId,
      source: DEMO_SOURCE,
      limit: '12'
    },
    body: {}
  });
}

async function readTimeline(context) {
  return callHandler(timelineHandler, {
    method: 'GET',
    url: '/api/run-log/timeline',
    headers: adminHeaders(),
    query: {
      subject_person_id: DEMO_SUBJECT_PERSON_ID,
      organization_id: context.organizationId,
      limit: '12'
    },
    body: {}
  });
}

function productionUrls(context) {
  const baseUrl = String(process.env.PGHD_DEMO_BASE_URL || process.env.PUBLIC_BASE_URL || DEMO_BASE_URL).replace(/\/$/, '');
  const common = {
    subject_person_id: DEMO_SUBJECT_PERSON_ID,
    organization_id: context.organizationId,
    source: DEMO_SOURCE,
    limit: '12'
  };
  return {
    preflight: `${baseUrl}/api/run-log/preflight?${qs({ ...common, limit: '5' })}`,
    encounterInsights: `${baseUrl}/api/run-log/encounter-insights?${qs({ ...common, org_client_profile_id: context.orgClientProfileId })}`,
    stateSnapshots: `${baseUrl}/api/run-log/state-snapshots?${qs({ ...common, org_client_profile_id: context.orgClientProfileId })}`,
    timeline: `${baseUrl}/api/run-log/timeline?${qs({ subject_person_id: DEMO_SUBJECT_PERSON_ID, organization_id: context.organizationId, limit: '12' })}`
  };
}

function assertSeedOutput({ state, insights, preflight, timeline }) {
  const stateTypes = new Set((state.snapshots || []).map((snapshot) => snapshot.stateType));
  for (const type of ['training_load', 'adherence', 'fatigue']) {
    if (!stateTypes.has(type)) throw new Error(`demo state is missing ${type}`);
  }

  const inputCount = (state.snapshots || []).reduce((sum, snapshot) => sum + (snapshot.inputs || []).length, 0);
  const activityEventInputCount = (state.snapshots || []).reduce(
    (sum, snapshot) => sum + (snapshot.inputs || []).filter((input) => input.pghdActivityEventId).length,
    0
  );
  if (inputCount < 3) throw new Error('demo state snapshots did not include enough run_log_run provenance inputs');
  if (activityEventInputCount < 3) throw new Error('demo state snapshots did not include pghd_activity_event_id provenance inputs');
  if (!Number.isFinite(Number(insights.count)) || Number(insights.count) < 1) {
    throw new Error('demo encounter insights were not generated');
  }
  if (!Number.isFinite(Number(timeline.count)) || Number(timeline.count) < 1) {
    throw new Error('demo timeline did not include activity rows');
  }

  const checks = new Map((preflight.checks || []).map((item) => [item.name, item.status]));
  for (const name of ['physio_person_context', 'connection_mapping', 'activity_ingest', 'weekly_summary', 'state_materialization']) {
    if (checks.get(name) !== 'ok') throw new Error(`demo preflight ${name} was ${checks.get(name) || 'missing'}`);
  }
}

async function main() {
  ensureRuntimeEnv();
  const checkOnly = process.argv.includes('--check');
  const membership = await findBootstrapMembership();
  if (!membership?.organization_id || !membership?.person_id) {
    throw new Error('PGHD demo seed requires an active PhysioApp organization_members provider/staff row');
  }

  const person = checkOnly ? { id: DEMO_SUBJECT_PERSON_ID } : await upsertPerson();
  const organizationMember = checkOnly
    ? null
    : await ensureOrganizationMember({ organizationId: membership.organization_id });
  const orgClient = checkOnly
    ? (await supabaseFetch(
        `/org_clients?${qs({
          select: 'id,organization_id,person_id,status',
          organization_id: `eq.${membership.organization_id}`,
          person_id: `eq.${DEMO_SUBJECT_PERSON_ID}`,
          limit: '1'
        })}`
      ))?.[0]
    : await ensureOrgClient({
        organizationId: membership.organization_id,
        providerPersonId: membership.person_id
      });
  if (!orgClient?.id) throw new Error('demo org client context does not exist; run without --check first');

  const orgClientProfile = checkOnly
    ? (await supabaseFetch(
        `/org_client_profile?${qs({
          select: 'id,organization_id,person_id',
          organization_id: `eq.${membership.organization_id}`,
          person_id: `eq.${DEMO_SUBJECT_PERSON_ID}`,
          limit: '1'
        })}`
      ))?.[0]
    : await ensureOrgClientProfile({ organizationId: membership.organization_id });
  if (!orgClientProfile?.id) throw new Error('demo org client profile does not exist; run without --check first');

  const connection = checkOnly
    ? (await supabaseFetch(
        `/pghd_connections?${qs({
          select: 'id,person_id,provider,provider_user_id',
          person_id: `eq.${DEMO_SUBJECT_PERSON_ID}`,
          provider_user_id: `eq.${DEMO_PROVIDER_USER_ID}`,
          limit: '1'
        })}`
      ))?.[0]
    : await ensureConnection({
        organizationId: membership.organization_id,
        providerPersonId: membership.person_id
      });
  if (!connection?.id) throw new Error('demo PGHD connection does not exist; run without --check first');

  const context = {
    organizationId: membership.organization_id,
    providerPersonId: membership.person_id,
    orgClientId: orgClient.id,
    orgClientProfileId: orgClientProfile.id,
    pghdConnectionId: connection.id
  };

  const runs = checkOnly ? [] : await upsertDemoRuns(context);
  if (!checkOnly) await materializeState(context);
  const state = await readState(context);
  const insights = await readInsights(context);
  const preflight = await readPreflight(context);
  const timeline = await readTimeline(context);
  assertSeedOutput({ state, insights, preflight, timeline });

  const sourceActivities = (insights.insights || []).flatMap((insight) => insight.sourceActivities || []);
  const stateInputCount = (state.snapshots || []).reduce((sum, snapshot) => sum + (snapshot.inputs || []).length, 0);
  const stateActivityEventInputCount = (state.snapshots || []).reduce(
    (sum, snapshot) => sum + (snapshot.inputs || []).filter((input) => input.pghdActivityEventId).length,
    0
  );

  console.log(JSON.stringify({
    ok: true,
    mode: checkOnly ? 'check' : 'seed',
    personId: person.id,
    organizationId: context.organizationId,
    providerPersonId: context.providerPersonId,
    organizationMemberId: organizationMember?.id,
    orgClientId: context.orgClientId,
    orgClientProfileId: context.orgClientProfileId,
    pghdConnectionId: context.pghdConnectionId,
    provider: DEMO_SOURCE,
    providerUserId: DEMO_PROVIDER_USER_ID,
    seededRunCount: checkOnly ? undefined : runs.length,
    stateSnapshotCount: state.count,
    stateInputLinkCount: stateInputCount,
    stateActivityEventInputLinkCount: stateActivityEventInputCount,
    insightCount: insights.count,
    sourceActivityCount: sourceActivities.length,
    timelineCount: timeline.count,
    preflightStatus: preflight.summary?.status,
    productionSmokeUrls: productionUrls(context)
  }, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(JSON.stringify({
      ok: false,
      error: error.message
    }, null, 2));
    process.exit(1);
  });
}
