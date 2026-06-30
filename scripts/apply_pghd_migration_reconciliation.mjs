#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import {
  planPghdMigrationReconciliation
} from './plan_pghd_migration_reconciliation.mjs';
import { buildPghdReleaseReadiness } from './check_pghd_release_readiness.mjs';

export const reconciliationApplyToken = '20260622145528';

export function requireReconciliationApplyConfirmation(env = process.env) {
  if (env.PGHD_MIGRATION_RECONCILE_APPLY !== reconciliationApplyToken) {
    throw new Error(
      `set PGHD_MIGRATION_RECONCILE_APPLY=${reconciliationApplyToken} to fetch remote migration history and repair PGHD local-only versions`
    );
  }
}

export function buildReconciliationApplySteps(plan) {
  const actions = Array.isArray(plan?.actions) ? plan.actions : [];
  const fetchAction = actions.find((action) => action.name === 'fetch_remote_history' && action.eligible);
  const repairAction = actions.find((action) => action.name === 'repair_pghd_local_only_versions' && action.eligible);
  const steps = [];

  if (fetchAction) {
    steps.push({
      name: 'fetch linked remote migration history',
      command: 'supabase',
      args: ['migration', 'fetch', '--linked']
    });
  }

  if (repairAction) {
    const pending = Array.isArray(plan.pending) ? plan.pending : [];
    steps.push({
      name: 'mark PGHD local-only migrations applied',
      command: 'supabase',
      args: ['migration', 'repair', ...pending, '--status', 'applied', '--linked']
    });
  }

  steps.push({
    name: 'verify PGHD release readiness after reconciliation',
    command: 'npm',
    args: ['run', 'check:pghd:release-readiness']
  });

  return steps;
}

export function assertReconciliationPlanExecutable(plan) {
  if (!plan?.functionalOk) {
    throw new Error(`PGHD functional checks are not green: ${plan?.functionalError || 'unknown error'}`);
  }

  if (Array.isArray(plan.missing) && plan.missing.length > 0) {
    throw new Error(`required PGHD migrations are missing locally: ${plan.missing.join(',')}`);
  }

  const repairAction = Array.isArray(plan.actions)
    ? plan.actions.find((action) => action.name === 'repair_pghd_local_only_versions')
    : null;
  if (repairAction && !repairAction.eligible) {
    throw new Error('PGHD migration repair action is not eligible; rerun the reconciliation plan and inspect blockers');
  }
}

export function runStep(step, { spawnFn = spawn, env = process.env, log = console.log } = {}) {
  return new Promise((resolve, reject) => {
    log(`\n==> ${step.name}`);
    const child = spawnFn(step.command, step.args, {
      stdio: 'inherit',
      env
    });

    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${step.name} failed with exit code ${code}`));
    });
  });
}

export async function runReconciliationApplyWorkflow({
  env = process.env,
  planner = planPghdMigrationReconciliation,
  runStepFn = runStep
} = {}) {
  requireReconciliationApplyConfirmation(env);

  const plan = await planner({ env });
  assertReconciliationPlanExecutable(plan);

  const steps = buildReconciliationApplySteps(plan);
  for (const step of steps) {
    await runStepFn(step, { env });
  }

  return buildPghdReleaseReadiness({
    status: {
      ok: true,
      preflightSurfaceOk: true,
      functionalOk: true,
      migrationHistoryOk: true,
      recommendedApplyPath: plan.localMigrationHistoryOk ? 'run-log-db-push' : 'physio-app-owner-lineage',
      dbPushAllowed: Boolean(plan.localMigrationHistoryOk && !plan.dbPushBlocked),
      dbPushBlocked: Boolean(plan.dbPushBlocked),
      ownerBridgeApplied: Boolean(plan.ownerBridgeApplied),
      localMigrationHistoryOk: Boolean(plan.localMigrationHistoryOk)
    },
    reconciliationPlan: plan
  });
}

async function main() {
  const readiness = await runReconciliationApplyWorkflow();
  console.log(JSON.stringify(readiness, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`\nPGHD migration reconciliation workflow failed: ${error.message}`);
    process.exit(1);
  });
}
