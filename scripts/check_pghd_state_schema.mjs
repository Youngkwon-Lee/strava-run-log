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

async function checkPostgrestSelect(name, path) {
  try {
    await supabaseFetch(path);
    return { name, ok: true };
  } catch (error) {
    return { name, ok: false, error: error.message };
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function retryCount(env = process.env) {
  return Math.max(1, Math.min(30, Number(env.PGHD_SCHEMA_CHECK_RETRIES || 1)));
}

export function retryDelayMs(env = process.env) {
  return Math.max(250, Math.min(10000, Number(env.PGHD_SCHEMA_CHECK_RETRY_MS || 2000)));
}

async function runChecks() {
  return Promise.all([
    checkPostgrestSelect(
      'run_log_runs activity-event columns',
      '/run_log_runs?select=activity_type,ended_at,max_heartrate,calories,source_record_type,imported_at&limit=1'
    ),
    checkPostgrestSelect(
      'human_state_snapshots table',
      '/human_state_snapshots?select=id,subject_person_id,state_type,value,confidence,calculated_at,source,provider_source&limit=1'
    ),
    checkPostgrestSelect(
      'human_state_snapshot_inputs table',
      '/human_state_snapshot_inputs?select=snapshot_id,run_log_run_id,weight&limit=1'
    )
  ]);
}

export async function runChecksWithRetries({
  checkRunner,
  maxAttempts = retryCount(),
  delayMs = retryDelayMs(),
  sleepFn = sleep
} = {}) {
  const runner = checkRunner || runChecks;
  let checks = [];
  let attempts = 0;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    attempts = attempt;
    checks = await runner();
    if (checks.every((check) => check.ok)) break;
    if (attempt < maxAttempts) await sleepFn(delayMs);
  }

  return { checks, attempts, maxAttempts };
}

async function main() {
  loadFallbackEnv();
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('missing SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  }

  const { checks, attempts, maxAttempts } = await runChecksWithRetries();

  const ok = checks.every((check) => check.ok);
  console.log(JSON.stringify({
    ok,
    migration: '20260622145528_add_activity_event_state_snapshots',
    attempts,
    maxAttempts,
    checks
  }, null, 2));

  if (!ok) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exit(1);
  });
}
