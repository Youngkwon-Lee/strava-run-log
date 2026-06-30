#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
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

function maskRows(rows, fields) {
  return (rows || []).slice(0, 5).map((row) => Object.fromEntries(
    fields.map((field) => [field, row[field] || null])
  ));
}

export function buildSmokeCleanupReport({ bootstrapConnections = [], smokeRuns = [], activeSmokePersons = [] } = {}) {
  const counts = {
    leftoverBootstrapConnections: bootstrapConnections.length,
    leftoverSmokeRuns: smokeRuns.length,
    activeSmokePersons: activeSmokePersons.length
  };
  const ok = Object.values(counts).every((count) => count === 0);
  return {
    ok,
    ...counts,
    samples: {
      bootstrapConnections: maskRows(bootstrapConnections, ['id', 'provider_user_id']),
      smokeRuns: maskRows(smokeRuns, ['id', 'external_id']),
      activeSmokePersons: maskRows(activeSmokePersons, ['id', 'first_name', 'last_name'])
    }
  };
}

export async function collectSmokeCleanupReport(fetcher = supabaseFetch) {
  const [bootstrapConnections, smokeRuns, activeSmokePersons] = await Promise.all([
    fetcher('/pghd_connections?select=id,provider_user_id&provider_user_id=like.pghd-smoke-bootstrap-*'),
    fetcher('/run_log_runs?select=id,external_id&external_id=like.apple_health_pghd_smoke_*'),
    fetcher('/persons?select=id,first_name,last_name,is_active,anonymized_at&first_name=eq.PGHD&last_name=like.Smoke-*&is_active=eq.true')
  ]);

  return buildSmokeCleanupReport({
    bootstrapConnections: bootstrapConnections || [],
    smokeRuns: smokeRuns || [],
    activeSmokePersons: activeSmokePersons || []
  });
}

async function main() {
  try {
    loadFallbackEnv();
    const report = await collectSmokeCleanupReport();
    console.log(JSON.stringify(report, null, 2));
    if (!report.ok) process.exit(1);
  } catch (error) {
    console.error(JSON.stringify({
      ok: false,
      error: error.message
    }, null, 2));
    process.exit(1);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
