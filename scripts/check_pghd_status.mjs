#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { checkRequiredMigrationHistory } from './check_pghd_migration_history.mjs';
import { runFunctionalChecks } from './check_pghd_state_functional.mjs';

function readRepoFile(path) {
  return readFileSync(resolve(process.cwd(), path), 'utf8');
}

export function checkPghdPreflightSurface() {
  const checks = [
    {
      name: 'preflight endpoint file',
      ok: existsSync(resolve(process.cwd(), 'api/run-log/preflight.js'))
    },
    {
      name: 'bridge contract exposes preflight',
      ok: /pghdPreflight/.test(readRepoFile('lib/bridge-contract.js'))
        && /\/api\/run-log\/preflight/.test(readRepoFile('lib/bridge-contract.js'))
    },
    {
      name: 'dashboard renders preflight panel',
      ok: /pghd-preflight-grid/.test(readRepoFile('index.html'))
        && /fetchPghdPreflight/.test(readRepoFile('index.html'))
    },
    {
      name: 'E2E smoke verifies preflight',
      ok: /\/api\/run-log\/preflight/.test(readRepoFile('scripts/smoke_pghd_e2e.mjs'))
        && /pghd preflight checked readiness/.test(readRepoFile('scripts/smoke_pghd_e2e.mjs'))
        && /physio_person_context/.test(readRepoFile('scripts/smoke_pghd_e2e.mjs'))
    },
    {
      name: 'strict staging smoke gates are exposed',
      ok: /"smoke:pghd:strict-full":/.test(readRepoFile('package.json'))
        && /"gate:pghd:strict-staging":/.test(readRepoFile('package.json'))
        && /check:pghd:smoke-cleanup/.test(readRepoFile('package.json'))
    },
    {
      name: 'smoke cleanup checker covers PGHD artifacts',
      ok: existsSync(resolve(process.cwd(), 'scripts/check_pghd_smoke_cleanup.mjs'))
        && /pghd-smoke-bootstrap/.test(readRepoFile('scripts/check_pghd_smoke_cleanup.mjs'))
        && /apple_health_pghd_smoke/.test(readRepoFile('scripts/check_pghd_smoke_cleanup.mjs'))
        && /activeSmokePersons/.test(readRepoFile('scripts/check_pghd_smoke_cleanup.mjs'))
    },
    {
      name: 'API contract documents preflight',
      ok: /GET \/api\/run-log\/preflight/.test(readRepoFile('docs/physio-app-api-contract.md'))
        && /physio_person_context/.test(readRepoFile('docs/physio-app-api-contract.md'))
        && /gate:pghd:strict-staging/.test(readRepoFile('docs/physio-app-api-contract.md'))
    }
  ];

  return {
    ok: checks.every((check) => check.ok),
    checks
  };
}

export function classifyPghdApplyPath(migrationHistory = {}) {
  if (migrationHistory.localMigrationHistoryOk && !migrationHistory.dbPushBlocked) {
    return {
      dbPushAllowed: true,
      recommendedApplyPath: 'run-log-db-push',
      applyPathMessage: 'Local migration history is reconciled; run-log Supabase db push is allowed after normal review.'
    };
  }

  if (migrationHistory.ownerBridgeApplied) {
    return {
      dbPushAllowed: false,
      recommendedApplyPath: 'physio-app-owner-lineage',
      applyPathMessage: 'Use the PhysioApp owner-lineage bridge path; broad run-log Supabase db push remains blocked.'
    };
  }

  return {
    dbPushAllowed: false,
    recommendedApplyPath: 'reconcile-migration-history',
    applyPathMessage: 'Reconcile linked Supabase migration history before applying migrations from this repo.'
  };
}

export async function buildPghdStatus({
  env = process.env,
  migrationHistoryChecker = checkRequiredMigrationHistory,
  functionalChecker = runFunctionalChecks,
  preflightSurfaceChecker = checkPghdPreflightSurface
} = {}) {
  let preflightSurface;
  try {
    preflightSurface = preflightSurfaceChecker({ env });
  } catch (error) {
    preflightSurface = {
      ok: false,
      error: error.message,
      checks: []
    };
  }

  let migrationHistory;
  try {
    migrationHistory = migrationHistoryChecker({ env });
  } catch (error) {
    migrationHistory = {
      ok: false,
      error: error.message
    };
  }

  let functional = { ok: true };
  try {
    await functionalChecker({ env });
  } catch (error) {
    functional = {
      ok: false,
      error: error.message
    };
  }
  const applyPath = classifyPghdApplyPath(migrationHistory);

  return {
    ok: Boolean(preflightSurface.ok && functional.ok && migrationHistory.ok),
    preflightSurfaceOk: Boolean(preflightSurface.ok),
    functionalOk: Boolean(functional.ok),
    migrationHistoryOk: Boolean(migrationHistory.ok),
    localMigrationHistoryOk: Boolean(migrationHistory.localMigrationHistoryOk),
    ownerBridgeApplied: Boolean(migrationHistory.ownerBridgeApplied),
    dbPushBlocked: Boolean(migrationHistory.dbPushBlocked),
    dbPushAllowed: applyPath.dbPushAllowed,
    recommendedApplyPath: applyPath.recommendedApplyPath,
    applyPathMessage: applyPath.applyPathMessage,
    preflightSurface,
    functional,
    migrationHistory
  };
}

async function main() {
  const status = await buildPghdStatus();
  console.log(JSON.stringify(status, null, 2));
  if (!status.ok) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exit(1);
  });
}
