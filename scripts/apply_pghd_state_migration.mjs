#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { checkRequiredMigrationHistory } from './check_pghd_migration_history.mjs';

export function workflowSteps(env = process.env) {
  return [
    {
      name: 'check required migration history',
      command: 'npm',
      args: ['run', 'check:pghd:migration-history']
    },
    {
      name: 'list migrations before push',
      command: 'supabase',
      args: ['migration', 'list', '--linked'],
      requiresDbPushReady: true
    },
    {
      name: 'push pending Supabase migrations',
      command: 'supabase',
      args: ['db', 'push', '--linked', '--yes'],
      requiresRemoteDbPassword: true
    },
    {
      name: 'list migrations after push',
      command: 'supabase',
      args: ['migration', 'list', '--linked']
    },
    {
      name: 'check state schema readiness',
      command: 'npm',
      args: ['run', 'check:pghd:state-schema'],
      env: {
        PGHD_SCHEMA_CHECK_RETRIES: env.PGHD_SCHEMA_CHECK_RETRIES || '10'
      }
    },
    {
      name: 'run state DB smoke',
      command: 'npm',
      args: ['run', 'smoke:pghd:state:db']
    },
    {
      name: 'run state materialization smoke',
      command: 'npm',
      args: ['run', 'smoke:pghd:state']
    }
  ];
}

export function requireRemoteDbPassword(env = process.env) {
  if (!env.SUPABASE_DB_PASSWORD) {
    throw new Error('missing SUPABASE_DB_PASSWORD; set it to the linked project database password before applying the migration');
  }
}

export function requireDbPushReady(migrationHistory = checkRequiredMigrationHistory()) {
  const pending = Array.isArray(migrationHistory.pending) ? migrationHistory.pending : [];
  const missing = Array.isArray(migrationHistory.missing) ? migrationHistory.missing : [];
  const nextActions = Array.isArray(migrationHistory.nextActions)
    ? migrationHistory.nextActions.map((action) => action.command).filter(Boolean)
    : [];

  if (migrationHistory.dbPushBlocked || pending.length > 0 || missing.length > 0) {
    const details = [
      migrationHistory.dbPushBlocked ? 'dbPushBlocked=true' : null,
      pending.length > 0 ? `pending=${pending.join(',')}` : null,
      missing.length > 0 ? `missing=${missing.join(',')}` : null
    ].filter(Boolean).join('; ');
    const actionText = nextActions.length > 0 ? ` Next actions: ${nextActions.join(' && ')}` : '';
    throw new Error(`linked Supabase migration history is not ready for db push (${details}).${actionText}`);
  }
}

export function runStep(step, { spawnFn = spawn, env = process.env, log = console.log } = {}) {
  return new Promise((resolve, reject) => {
    log(`\n==> ${step.name}`);
    const child = spawnFn(step.command, step.args, {
      stdio: 'inherit',
      env: {
        ...env,
        ...(step.env || {})
      }
    });

    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${step.name} failed with exit code ${code}`));
    });
  });
}

export async function runWorkflow({
  env = process.env,
  steps = workflowSteps(env),
  runStepFn = runStep,
  migrationHistoryChecker = checkRequiredMigrationHistory
} = {}) {
  for (const step of steps) {
    if (step.requiresDbPushReady || step.requiresRemoteDbPassword) {
      requireDbPushReady(migrationHistoryChecker({ env }));
    }
    if (step.requiresRemoteDbPassword) requireRemoteDbPassword(env);
    await runStepFn(step, { env });
  }
}

async function main() {
  await runWorkflow();

  console.log('\nPGHD state migration applied and verified.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`\nPGHD state migration workflow failed: ${error.message}`);
    process.exit(1);
  });
}
