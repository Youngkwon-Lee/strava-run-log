#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { supabaseFetch } from '../lib/supabase-rest.js';

const DEFAULT_BASE_URL = 'https://strava-run-log.vercel.app';
const DEFAULT_PHYSIO_APP_ENV_FILE = '/Users/youngkwon/projects/physio_app/.env.local';
const DEFAULT_LOCAL_SECRET_ENV_FILES = [
  '.secrets/run_log_admin.env',
  '.secrets/live_metrics.env'
];
const DEFAULT_LOG_WINDOW = '10m';
const DEFAULT_LOG_LIMIT = '50';
const DEFAULT_TIMEOUT_MS = 20000;
const VERCEL_LOGS_COMMAND = 'vercel logs';

const DASHBOARD_REQUIRED_STRINGS = [
  'PGHD Review Brief',
  '품질 컨텍스트',
  'Insight 품질'
];

const REQUIRED_PREFLIGHT_CHECKS = [
  'run_store_backend',
  'connection_mapping',
  'physio_person_context',
  'activity_ingest',
  'weekly_summary',
  'state_materialization'
];

function isTruthyEnv(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value || '').trim().toLowerCase());
}

function parseEnvFile(path) {
  const parsed = {};
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const match = trimmed.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
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
  const candidates = [
    ...DEFAULT_LOCAL_SECRET_ENV_FILES,
    process.env.PRODUCTION_SMOKE_ENV_FILE,
    process.env.PGHD_SMOKE_ENV_FILE,
    DEFAULT_PHYSIO_APP_ENV_FILE
  ].filter(Boolean);

  for (const path of candidates) {
    if (!existsSync(path)) continue;
    const parsed = parseEnvFile(path);

    process.env.SUPABASE_URL = process.env.SUPABASE_URL || parsed.SUPABASE_URL || parsed.NEXT_PUBLIC_SUPABASE_URL || '';
    process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || parsed.SUPABASE_SERVICE_ROLE_KEY || '';
    process.env.PRODUCTION_RUN_LOG_ADMIN_TOKEN = process.env.PRODUCTION_RUN_LOG_ADMIN_TOKEN || parsed.PRODUCTION_RUN_LOG_ADMIN_TOKEN || '';
    process.env.RUN_LOG_ADMIN_TOKEN = process.env.RUN_LOG_ADMIN_TOKEN || parsed.RUN_LOG_ADMIN_TOKEN || '';
    process.env.LIVE_METRICS_TOKEN = process.env.LIVE_METRICS_TOKEN || parsed.LIVE_METRICS_TOKEN || '';
  }
}

function normalizeBaseUrl(value) {
  return String(value || DEFAULT_BASE_URL).replace(/\/+$/, '');
}

function qs(params) {
  const search = new URLSearchParams(params);
  return search.toString();
}

function stripAnsi(value) {
  return String(value || '').replace(/\x1B\[[0-?]*[ -/]*[@-~]/g, '');
}

function assertCondition(condition, message) {
  if (!condition) throw new Error(message);
}

export function maskId(value) {
  const text = String(value || '');
  if (!text) return null;
  if (text.length <= 12) return '***';
  return `${text.slice(0, 8)}...${text.slice(-4)}`;
}

function getAdminToken(env = process.env) {
  return String(env.PRODUCTION_RUN_LOG_ADMIN_TOKEN || env.RUN_LOG_ADMIN_TOKEN || env.LIVE_METRICS_TOKEN || '').trim();
}

async function fetchText(url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(DEFAULT_TIMEOUT_MS) });
  return {
    status: response.status,
    ok: response.ok,
    text: await response.text()
  };
}

async function fetchJson(url, init = {}) {
  const response = await fetch(url, {
    ...init,
    signal: AbortSignal.timeout(DEFAULT_TIMEOUT_MS),
    headers: {
      'content-type': 'application/json',
      ...(init.headers || {})
    }
  });
  const text = await response.text();
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = null;
    }
  }
  return {
    status: response.status,
    ok: response.ok,
    json,
    text
  };
}

async function checkDashboardHtml(baseUrl) {
  const response = await fetchText(`${baseUrl}/index.html`);
  assertCondition(response.status === 200, `GET /index.html returned ${response.status}`);

  const missing = DASHBOARD_REQUIRED_STRINGS.filter((value) => !response.text.includes(value));
  assertCondition(!missing.length, `production dashboard is missing required strings: ${missing.join(', ')}`);

  return {
    status: response.status,
    requiredStrings: Object.fromEntries(DASHBOARD_REQUIRED_STRINGS.map((value) => [value, true]))
  };
}

async function checkUnauthorizedPost(baseUrl, path) {
  const response = await fetchJson(`${baseUrl}${path}`, {
    method: 'POST',
    body: '{}'
  });

  assertCondition(response.status === 401, `POST ${path} without token returned ${response.status}`);
  assertCondition(response.json?.error === 'unauthorized', `POST ${path} did not return unauthorized JSON`);

  return {
    status: response.status,
    error: response.json.error
  };
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
        select: 'id,person_id,status',
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

async function resolvePreflightSubject(env = process.env) {
  const explicit = String(
    env.PRODUCTION_PGHD_SUBJECT_PERSON_ID
      || env.PRODUCTION_SMOKE_SUBJECT_PERSON_ID
      || env.PGHD_SMOKE_SUBJECT_PERSON_ID
      || ''
  ).trim();

  if (explicit) {
    return {
      subjectPersonId: explicit,
      provider: 'apple-health',
      selectionMode: 'explicit_env',
      hasOrgClientContext: null,
      pghdConnectionId: null
    };
  }

  const rows = await supabaseFetch(
    `/pghd_connections?${qs({
      select: 'id,person_id,provider,provider_user_id,connection_status,updated_at',
      provider: 'in.(apple-health,apple_health)',
      person_id: 'not.is.null',
      order: 'updated_at.desc.nullslast',
      limit: '30'
    })}`
  );
  const connections = Array.isArray(rows) ? rows : [];
  const selected = (await firstConnectionWithOrgClientContext(connections)) || connections[0] || null;

  assertCondition(
    selected?.person_id,
    'no production PGHD apple-health connection was found; set PRODUCTION_PGHD_SUBJECT_PERSON_ID'
  );

  return {
    subjectPersonId: selected.person_id,
    provider: selected.provider || 'apple-health',
    selectionMode: selected.hasOrgClientContext ? 'existing_apple_health_with_org_client_context' : 'existing_apple_health_without_org_client_context',
    hasOrgClientContext: Boolean(selected.hasOrgClientContext),
    pghdConnectionId: selected.id || null
  };
}

export function buildProductionPreflightEvidence(preflight) {
  const preflightChecks = Object.fromEntries(
    (preflight?.checks || []).map((item) => [item.name, item.status])
  );
  const preflightWarnings = (preflight?.checks || [])
    .filter((item) => item.status !== 'ok')
    .map((item) => ({
      name: item.name,
      status: item.status,
      message: item.message,
      operatorHints: item.operatorHints || []
    }));

  return {
    preflightStatus: preflight?.summary?.status || null,
    preflightChecks,
    preflightWarnings,
    preflightNextActions: preflight?.nextActions || []
  };
}

async function checkProductionPreflight(baseUrl) {
  const token = getAdminToken();
  assertCondition(
    token,
    'missing PRODUCTION_RUN_LOG_ADMIN_TOKEN, RUN_LOG_ADMIN_TOKEN, or LIVE_METRICS_TOKEN for authenticated production preflight'
  );

  const subject = await resolvePreflightSubject();
  const params = qs({
    subject_person_id: subject.subjectPersonId,
    source: 'apple-health',
    limit: '5'
  });
  const response = await fetchJson(`${baseUrl}/api/run-log/preflight?${params}`, {
    method: 'GET',
    headers: {
      authorization: `Bearer ${token}`
    }
  });

  assertCondition(response.status === 200, `GET /api/run-log/preflight returned ${response.status}`);

  const evidence = buildProductionPreflightEvidence(response.json);
  for (const name of REQUIRED_PREFLIGHT_CHECKS) {
    assertCondition(
      evidence.preflightChecks[name] === 'ok',
      `production preflight ${name} was ${evidence.preflightChecks[name] || 'missing'}`
    );
  }
  assertCondition(evidence.preflightStatus === 'ok', `production preflight status was ${evidence.preflightStatus}`);

  return {
    subjectPersonId: maskId(subject.subjectPersonId),
    pghdConnectionId: maskId(subject.pghdConnectionId),
    subjectSelectionMode: subject.selectionMode,
    selectedOrgClientContext: subject.hasOrgClientContext,
    ...evidence
  };
}

export function buildVercelLogsArgs({ level, since = DEFAULT_LOG_WINDOW, limit = DEFAULT_LOG_LIMIT, env = process.env } = {}) {
  const args = [
    'logs',
    '--environment',
    'production',
    '--no-branch',
    '--level',
    level,
    '--since',
    since,
    '--no-follow',
    '--limit',
    String(limit),
    '--expand',
    '--no-color'
  ];

  const project = String(env.VERCEL_PROJECT_ID || env.VERCEL_PROJECT || env.VERCEL_PROJECT_NAME || '').trim();
  if (project) args.push('--project', project);

  const scope = String(env.VERCEL_SCOPE || '').trim();
  if (scope) args.push('--scope', scope);

  const token = String(env.VERCEL_TOKEN || '').trim();
  if (token) args.push('--token', token);

  return args;
}

function redactKnownSecrets(output, env = process.env) {
  let text = String(output || '');
  for (const key of [
    'VERCEL_TOKEN',
    'PRODUCTION_RUN_LOG_ADMIN_TOKEN',
    'RUN_LOG_ADMIN_TOKEN',
    'LIVE_METRICS_TOKEN',
    'SUPABASE_SERVICE_ROLE_KEY'
  ]) {
    const value = String(env[key] || '');
    if (value.length >= 8) text = text.split(value).join('[redacted]');
  }
  return text;
}

export function parseVercelLogOutput(output) {
  const noise = [
    /^Retrieving project/i,
    /^Fetching project/i,
    /^Fetching logs/i,
    /^No logs found for /i,
    /^> NOTE: The Vercel CLI now collects telemetry/i,
    /^> This information is used to shape the CLI roadmap/i,
    /^> You can learn more, including how to opt-out/i,
    /^> https:\/\/vercel\.com\/docs\/cli\/about-telemetry/i,
    /^─+$/,
    /^Update available! v[\d.]+/i,
    /^Changelog: https:\/\/github\.com\/vercel\/vercel\/releases\//i,
    /^Run `npm i -g vercel@latest` to update\./i,
    new RegExp(`^${VERCEL_LOGS_COMMAND}$`, 'i')
  ];
  const lines = stripAnsi(output)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((line) => !noise.some((pattern) => pattern.test(line)));

  return {
    hasLogs: lines.length > 0,
    sample: lines.slice(0, 8)
  };
}

function runCommand(command, args, { timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: process.cwd(),
      env: {
        ...process.env,
        VERCEL_TELEMETRY_DISABLED: process.env.VERCEL_TELEMETRY_DISABLED || '1'
      },
      stdio: ['ignore', 'pipe', 'pipe']
    });
    let stdout = '';
    let stderr = '';
    let timedOut = false;

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
    }, timeoutMs);

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.on('error', (error) => {
      clearTimeout(timer);
      resolve({ status: null, stdout, stderr, error, timedOut });
    });
    child.on('close', (status) => {
      clearTimeout(timer);
      resolve({ status, stdout, stderr, error: null, timedOut });
    });
  });
}

async function checkVercelLogs(level, since) {
  const args = buildVercelLogsArgs({ level, since });
  const result = await runCommand('vercel', args, { timeoutMs: 30000 });
  if (result.error) throw new Error(`${VERCEL_LOGS_COMMAND} failed: ${result.error.message}`);
  if (result.timedOut) throw new Error(`${VERCEL_LOGS_COMMAND} timed out`);

  const parsed = parseVercelLogOutput(redactKnownSecrets(`${result.stdout}\n${result.stderr}`));
  assertCondition(result.status === 0, `${VERCEL_LOGS_COMMAND} exited ${result.status}: ${parsed.sample.join(' | ')}`);
  assertCondition(!parsed.hasLogs, `production Vercel ${level} logs are not empty: ${parsed.sample.join(' | ')}`);

  return {
    level,
    since,
    empty: true
  };
}

async function runStep(steps, evidence, name, key, fn) {
  const startedAt = new Date().toISOString();
  try {
    const value = await fn();
    evidence[key] = value;
    steps.push({ name, ok: true, startedAt, completedAt: new Date().toISOString() });
  } catch (error) {
    steps.push({ name, ok: false, startedAt, completedAt: new Date().toISOString(), error: error.message });
    throw error;
  }
}

async function main() {
  const baseUrl = normalizeBaseUrl(process.env.PRODUCTION_SMOKE_BASE_URL || DEFAULT_BASE_URL);
  const logWindow = process.env.PRODUCTION_SMOKE_LOG_SINCE || DEFAULT_LOG_WINDOW;
  const startedAt = new Date().toISOString();
  const steps = [];
  const evidence = {};

  try {
    loadFallbackEnv();

    await runStep(steps, evidence, 'production dashboard PGHD surfaces load', 'dashboard', () => (
      checkDashboardHtml(baseUrl)
    ));
    await runStep(steps, evidence, 'live metrics rejects unauthenticated writes', 'liveMetricsUnauthenticated', () => (
      checkUnauthorizedPost(baseUrl, '/api/live/metrics')
    ));
    await runStep(steps, evidence, 'apple-health ingest rejects unauthenticated writes', 'appleHealthUnauthenticated', () => (
      checkUnauthorizedPost(baseUrl, '/api/apple-health/ingest')
    ));

    if (isTruthyEnv(process.env.PRODUCTION_SMOKE_SKIP_PREFLIGHT)) {
      evidence.preflight = { skipped: true };
      steps.push({
        name: 'authenticated production PGHD preflight',
        ok: true,
        skipped: true,
        startedAt: new Date().toISOString(),
        completedAt: new Date().toISOString()
      });
    } else {
      await runStep(steps, evidence, 'authenticated production PGHD preflight', 'preflight', () => (
        checkProductionPreflight(baseUrl)
      ));
    }

    if (isTruthyEnv(process.env.PRODUCTION_SMOKE_SKIP_LOGS)) {
      evidence.vercelLogs = { skipped: true };
      steps.push({
        name: 'production Vercel error/warning logs',
        ok: true,
        skipped: true,
        startedAt: new Date().toISOString(),
        completedAt: new Date().toISOString()
      });
    } else {
      await runStep(steps, evidence, 'production Vercel error logs are empty', 'vercelErrorLogs', () => (
        checkVercelLogs('error', logWindow)
      ));
      await runStep(steps, evidence, 'production Vercel warning logs are empty', 'vercelWarningLogs', () => (
        checkVercelLogs('warning', logWindow)
      ));
    }

    console.log(JSON.stringify({
      ok: true,
      source: 'production-readiness-smoke',
      baseUrl,
      startedAt,
      completedAt: new Date().toISOString(),
      steps,
      evidence
    }, null, 2));
  } catch (error) {
    console.error(JSON.stringify({
      ok: false,
      source: 'production-readiness-smoke',
      baseUrl,
      startedAt,
      completedAt: new Date().toISOString(),
      error: error.message,
      steps,
      evidence
    }, null, 2));
    process.exit(1);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
