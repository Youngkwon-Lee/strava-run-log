#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const directSqlApplyToken = '20260622145528';

export function requireDirectSqlApplyConfirmation(env = process.env) {
  if (env.PGHD_DIRECT_SQL_APPLY !== directSqlApplyToken) {
    throw new Error(`set PGHD_DIRECT_SQL_APPLY=${directSqlApplyToken} to apply idempotent SQL directly without migration history changes`);
  }
}

export function directSqlSteps() {
  return [
    {
      name: 'apply activity-event state snapshot SQL directly',
      command: 'supabase',
      args: ['db', 'query', '--linked', '--file', 'supabase/migrations/20260622145528_add_activity_event_state_snapshots.sql', '-o', 'table']
    },
    {
      name: 'check state schema readiness',
      command: 'npm',
      args: ['run', 'check:pghd:state-schema'],
      env: {
        PGHD_SCHEMA_CHECK_RETRIES: '10'
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

export async function runDirectSqlWorkflow({ env = process.env, steps = directSqlSteps(), runStepFn = runStep } = {}) {
  requireDirectSqlApplyConfirmation(env);

  for (const step of steps) {
    await runStepFn(step, { env });
  }
}

async function main() {
  await runDirectSqlWorkflow();
  console.log('\nPGHD state SQL applied directly and verified. Migration history was not changed.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`\nPGHD direct SQL apply workflow failed: ${error.message}`);
    process.exit(1);
  });
}
