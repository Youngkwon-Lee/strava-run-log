#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const requiredMigrations = [
  '20260622014705',
  '20260622023954',
  '20260622040100',
  '20260622043000',
  '20260622145528'
];

export const ownerBridgeMigrationVersion = '20260622162503';

export function migrationListTimeoutMs(env = process.env) {
  const defaultTimeoutMs = 60000;
  const value = Number(env.PGHD_MIGRATION_LIST_TIMEOUT_MS || defaultTimeoutMs);
  return Math.max(5000, Math.min(120000, Number.isFinite(value) ? value : defaultTimeoutMs));
}

export function parseMigrationList(output) {
  const rows = [];
  for (const line of String(output || '').split(/\r?\n/)) {
    const match = line.match(/^\s*(\d{14})?\s*\|\s*(\d{14})?\s*\|/);
    if (!match) continue;
    const local = match[1] || null;
    const remote = match[2] || null;
    if (!local && !remote) continue;
    rows.push({ local, remote });
  }
  return rows;
}

export function summarizeRequiredMigrations(rows, required = requiredMigrations) {
  return required.map((version) => {
    const local = rows.some((row) => row.local === version);
    const remote = rows.some((row) => row.remote === version);
    const status = local && remote ? 'applied' : local ? 'pending' : remote ? 'remote-only' : 'missing';
    return { version, local, remote, status };
  });
}

export function buildMigrationHistoryNextActions({
  pending = [],
  missing = [],
  remoteOnlyCount = 0
} = {}) {
  const actions = [];

  if (remoteOnlyCount > 0) {
    actions.push({
      reason: 'remote migration history contains versions that are not present under supabase/migrations',
      command: 'supabase migration fetch --linked',
      note: 'review the fetched files before committing; this unblocks Supabase CLI history comparison for the linked project'
    });
  }

  if (pending.length > 0) {
    actions.push({
      reason: 'local PGHD migrations are present but not marked applied in remote migration history',
      command: `supabase migration repair ${pending.join(' ')} --status applied --linked`,
      note: 'only run after schema and PGHD smoke checks prove the SQL is already present on the linked database'
    });
  }

  if (missing.length > 0) {
    actions.push({
      reason: 'required PGHD migration files are missing locally',
      command: `restore or recreate missing migration files: ${missing.join(', ')}`,
      note: 'do not repair missing versions until the local migration file and database schema have been audited'
    });
  }

  return actions;
}

function runMigrationList({ spawnFn = spawnSync, env = process.env } = {}) {
  const result = spawnFn('supabase', ['migration', 'list', '--linked'], {
    encoding: 'utf8',
    timeout: migrationListTimeoutMs(env)
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`supabase migration list failed with exit code ${result.status}: ${output.trim()}`);
  }
  return output;
}

export function checkRequiredMigrationHistory({ listOutput, spawnFn, env } = {}) {
  const output = listOutput ?? runMigrationList({ spawnFn, env });
  const rows = parseMigrationList(output);
  const migrations = summarizeRequiredMigrations(rows);
  const missing = migrations.filter((migration) => migration.status === 'missing');
  const pending = migrations.filter((migration) => migration.status === 'pending');
  const applied = migrations.filter((migration) => migration.status === 'applied');
  const remoteOnly = rows
    .filter((row) => row.remote && !row.local)
    .map((row) => row.remote);
  const localMigrationHistoryOk = missing.length === 0 && pending.length === 0 && remoteOnly.length === 0;
  const ownerBridgeApplied = rows.some((row) => row.remote === ownerBridgeMigrationVersion);
  const nextActions = buildMigrationHistoryNextActions({
    pending: pending.map((migration) => migration.version),
    missing: missing.map((migration) => migration.version),
    remoteOnlyCount: remoteOnly.length
  });
  return {
    ok: localMigrationHistoryOk || ownerBridgeApplied,
    localMigrationHistoryOk,
    ownerBridgeMigrationVersion,
    ownerBridgeApplied,
    required: migrations,
    pending: pending.map((migration) => migration.version),
    applied: applied.map((migration) => migration.version),
    missing: missing.map((migration) => migration.version),
    remoteOnlyCount: remoteOnly.length,
    remoteOnlySample: remoteOnly.slice(0, 12),
    dbPushBlocked: remoteOnly.length > 0,
    nextActions
  };
}

function main() {
  const result = checkRequiredMigrationHistory();
  console.log(JSON.stringify(result, null, 2));
  if (!result.ok) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exit(1);
  }
}
