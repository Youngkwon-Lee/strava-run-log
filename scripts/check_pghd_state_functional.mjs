#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export function functionalCheckSteps(env = process.env) {
  return [
    {
      name: 'check state schema readiness',
      command: 'npm',
      args: ['run', 'check:pghd:state-schema'],
      env: {
        PGHD_SCHEMA_CHECK_RETRIES: env.PGHD_SCHEMA_CHECK_RETRIES || '3'
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

export async function runFunctionalChecks({
  env = process.env,
  steps = functionalCheckSteps(env),
  runStepFn = runStep
} = {}) {
  for (const step of steps) {
    await runStepFn(step, { env });
  }
}

async function main() {
  await runFunctionalChecks();
  console.log('\nPGHD state functional checks passed. This does not imply Supabase migration history is reconciled.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`\nPGHD state functional check failed: ${error.message}`);
    process.exit(1);
  });
}
