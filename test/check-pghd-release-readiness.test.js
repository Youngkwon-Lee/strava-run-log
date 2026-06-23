import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildPghdReleaseReadiness,
  checkPghdReleaseReadiness
} from '../scripts/check_pghd_release_readiness.mjs';

test('buildPghdReleaseReadiness accepts owner-lineage path with functional reconciliation proof', () => {
  const readiness = buildPghdReleaseReadiness({
    status: {
      ok: true,
      preflightSurfaceOk: true,
      functionalOk: true,
      migrationHistoryOk: true,
      recommendedApplyPath: 'physio-app-owner-lineage',
      dbPushAllowed: false,
      dbPushBlocked: true,
      ownerBridgeApplied: true,
      localMigrationHistoryOk: false
    },
    reconciliationPlan: {
      functionalOk: true,
      missing: [],
      actions: [
        { name: 'fetch_remote_history', eligible: true },
        { name: 'repair_pghd_local_only_versions', eligible: true }
      ]
    }
  });

  assert.equal(readiness.ok, true);
  assert.equal(readiness.recommendedApplyPath, 'physio-app-owner-lineage');
  assert.equal(readiness.dbPushAllowed, false);
  assert.deepEqual(readiness.blockers, []);
  assert.deepEqual(readiness.eligibleReconciliationActions, [
    'fetch_remote_history',
    'repair_pghd_local_only_versions'
  ]);
});

test('buildPghdReleaseReadiness accepts clean run-log db push path', () => {
  const readiness = buildPghdReleaseReadiness({
    status: {
      ok: true,
      preflightSurfaceOk: true,
      functionalOk: true,
      migrationHistoryOk: true,
      recommendedApplyPath: 'run-log-db-push',
      dbPushAllowed: true,
      dbPushBlocked: false,
      ownerBridgeApplied: false,
      localMigrationHistoryOk: true
    },
    reconciliationPlan: {
      functionalOk: true,
      missing: [],
      actions: []
    }
  });

  assert.equal(readiness.ok, true);
  assert.equal(readiness.dbPushAllowed, true);
  assert.deepEqual(readiness.blockers, []);
});

test('buildPghdReleaseReadiness blocks unknown or unproven apply paths', () => {
  const readiness = buildPghdReleaseReadiness({
    status: {
      ok: true,
      preflightSurfaceOk: true,
      functionalOk: true,
      migrationHistoryOk: true,
      recommendedApplyPath: 'reconcile-migration-history',
      dbPushAllowed: false,
      dbPushBlocked: true,
      ownerBridgeApplied: false,
      localMigrationHistoryOk: false
    },
    reconciliationPlan: {
      functionalOk: true,
      missing: [],
      actions: []
    }
  });

  assert.equal(readiness.ok, false);
  assert.deepEqual(readiness.blockers, ['apply_path_not_accepted', 'no_verified_apply_path']);
});

test('checkPghdReleaseReadiness combines status and reconciliation plan', async () => {
  const calls = [];
  const readiness = await checkPghdReleaseReadiness({
    env: { PGHD_SCHEMA_CHECK_RETRIES: '2' },
    statusBuilder: async ({ env }) => {
      calls.push(['status', env]);
      return {
        ok: true,
        preflightSurfaceOk: true,
        functionalOk: true,
        migrationHistoryOk: true,
        recommendedApplyPath: 'physio-app-owner-lineage',
        dbPushAllowed: false,
        dbPushBlocked: true,
        ownerBridgeApplied: true,
        localMigrationHistoryOk: false,
        migrationHistory: {
          ok: true,
          localMigrationHistoryOk: false,
          ownerBridgeApplied: true,
          dbPushBlocked: true,
          pending: [],
          missing: [],
          remoteOnlyCount: 0
        }
      };
    },
    reconciliationPlanBuilder: ({ migrationHistory, functionalOk, functionalError }) => {
      calls.push(['plan', { migrationHistory, functionalOk, functionalError }]);
      return {
        functionalOk: true,
        missing: [],
        actions: []
      };
    }
  });

  assert.equal(readiness.ok, true);
  assert.equal(calls[0][0], 'status');
  assert.deepEqual(calls[0][1], { PGHD_SCHEMA_CHECK_RETRIES: '2' });
  assert.equal(calls[1][0], 'plan');
  assert.equal(calls[1][1].functionalOk, true);
  assert.equal(calls[1][1].migrationHistory.ownerBridgeApplied, true);
});
