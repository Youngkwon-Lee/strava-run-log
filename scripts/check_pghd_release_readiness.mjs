#!/usr/bin/env node

import { pathToFileURL } from 'node:url';
import { buildPghdStatus } from './check_pghd_status.mjs';
import { buildReconciliationPlan } from './plan_pghd_migration_reconciliation.mjs';

export function buildPghdReleaseReadiness({
  status,
  reconciliationPlan,
  acceptedApplyPaths = ['run-log-db-push', 'physio-app-owner-lineage']
} = {}) {
  const recommendedApplyPath = status?.recommendedApplyPath || 'unknown';
  const applyPathAccepted = acceptedApplyPaths.includes(recommendedApplyPath);
  const ownerLineageReady = recommendedApplyPath === 'physio-app-owner-lineage'
    && status?.ownerBridgeApplied
    && reconciliationPlan?.functionalOk
    && Array.isArray(reconciliationPlan?.missing)
    && reconciliationPlan.missing.length === 0;
  const dbPushReady = recommendedApplyPath === 'run-log-db-push'
    && status?.dbPushAllowed
    && status?.localMigrationHistoryOk;
  const ready = Boolean(
    status?.ok
      && status?.preflightSurfaceOk
      && status?.functionalOk
      && status?.migrationHistoryOk
      && applyPathAccepted
      && (ownerLineageReady || dbPushReady)
  );
  const blockers = [];

  if (!status?.ok) blockers.push('pghd_status_not_ok');
  if (!status?.preflightSurfaceOk) blockers.push('preflight_surface_not_ok');
  if (!status?.functionalOk) blockers.push('functional_checks_not_ok');
  if (!status?.migrationHistoryOk) blockers.push('migration_history_not_ok');
  if (!applyPathAccepted) blockers.push('apply_path_not_accepted');
  if (!ownerLineageReady && !dbPushReady) blockers.push('no_verified_apply_path');

  return {
    ok: ready,
    recommendedApplyPath,
    dbPushAllowed: Boolean(status?.dbPushAllowed),
    dbPushBlocked: Boolean(status?.dbPushBlocked),
    ownerBridgeApplied: Boolean(status?.ownerBridgeApplied),
    localMigrationHistoryOk: Boolean(status?.localMigrationHistoryOk),
    reconciliationFunctionalOk: Boolean(reconciliationPlan?.functionalOk),
    reconciliationMissing: reconciliationPlan?.missing || [],
    eligibleReconciliationActions: Array.isArray(reconciliationPlan?.actions)
      ? reconciliationPlan.actions.filter((action) => action.eligible).map((action) => action.name)
      : [],
    blockers
  };
}

export async function checkPghdReleaseReadiness({
  env = process.env,
  statusBuilder = buildPghdStatus,
  reconciliationPlanBuilder = buildReconciliationPlan
} = {}) {
  const status = await statusBuilder({ env });
  const reconciliationPlan = reconciliationPlanBuilder({
    migrationHistory: status.migrationHistory,
    functionalOk: status.functionalOk,
    functionalError: status.functional?.error || null
  });
  return buildPghdReleaseReadiness({ status, reconciliationPlan });
}

async function main() {
  const readiness = await checkPghdReleaseReadiness();
  console.log(JSON.stringify(readiness, null, 2));
  if (!readiness.ok) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exit(1);
  });
}
