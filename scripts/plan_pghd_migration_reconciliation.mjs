#!/usr/bin/env node

import { pathToFileURL } from 'node:url';
import { checkRequiredMigrationHistory } from './check_pghd_migration_history.mjs';
import { runFunctionalChecks } from './check_pghd_state_functional.mjs';

export function buildReconciliationPlan({
  migrationHistory,
  functionalOk,
  functionalError = null
} = {}) {
  const pending = Array.isArray(migrationHistory?.pending) ? migrationHistory.pending : [];
  const missing = Array.isArray(migrationHistory?.missing) ? migrationHistory.missing : [];
  const remoteOnlyCount = Number(migrationHistory?.remoteOnlyCount || 0);
  const actions = [];

  if (remoteOnlyCount > 0) {
    actions.push({
      name: 'fetch_remote_history',
      eligible: true,
      command: 'supabase migration fetch --linked',
      reason: 'remote migration history contains versions that are not present under supabase/migrations'
    });
  }

  if (pending.length > 0) {
    actions.push({
      name: 'repair_pghd_local_only_versions',
      eligible: Boolean(functionalOk && missing.length === 0),
      command: `supabase migration repair ${pending.join(' ')} --status applied --linked`,
      reason: functionalOk
        ? 'PGHD schema and state smokes passed, so these already-present local versions can be marked applied after review'
        : 'functional schema proof is missing; do not repair migration history yet'
    });
  }

  if (missing.length > 0) {
    actions.push({
      name: 'restore_missing_required_migrations',
      eligible: false,
      command: `restore or recreate missing migration files: ${missing.join(', ')}`,
      reason: 'required PGHD migration files are missing locally'
    });
  }

  return {
    ok: Boolean(functionalOk && migrationHistory?.ok && missing.length === 0),
    functionalOk: Boolean(functionalOk),
    functionalError,
    localMigrationHistoryOk: Boolean(migrationHistory?.localMigrationHistoryOk),
    ownerBridgeApplied: Boolean(migrationHistory?.ownerBridgeApplied),
    dbPushBlocked: Boolean(migrationHistory?.dbPushBlocked),
    pending,
    missing,
    remoteOnlyCount,
    remoteOnlySample: migrationHistory?.remoteOnlySample || [],
    actions
  };
}

export async function planPghdMigrationReconciliation({
  env = process.env,
  migrationHistoryChecker = checkRequiredMigrationHistory,
  functionalChecker = runFunctionalChecks
} = {}) {
  const migrationHistory = migrationHistoryChecker({ env });
  let functionalOk = true;
  let functionalError = null;

  try {
    await functionalChecker({ env });
  } catch (error) {
    functionalOk = false;
    functionalError = error.message;
  }

  return buildReconciliationPlan({
    migrationHistory,
    functionalOk,
    functionalError
  });
}

async function main() {
  const plan = await planPghdMigrationReconciliation();
  console.log(JSON.stringify(plan, null, 2));
  if (!plan.functionalOk) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exit(1);
  });
}
