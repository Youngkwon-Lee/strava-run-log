import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildReconciliationPlan,
  planPghdMigrationReconciliation
} from '../scripts/plan_pghd_migration_reconciliation.mjs';

test('buildReconciliationPlan marks repair eligible only after functional proof', () => {
  const plan = buildReconciliationPlan({
    functionalOk: true,
    migrationHistory: {
      ok: true,
      localMigrationHistoryOk: false,
      ownerBridgeApplied: true,
      dbPushBlocked: true,
      pending: ['20260622145528'],
      missing: [],
      remoteOnlyCount: 2,
      remoteOnlySample: ['20260215234342']
    }
  });

  assert.equal(plan.ok, true);
  assert.equal(plan.actions[0].name, 'fetch_remote_history');
  assert.equal(plan.actions[0].eligible, true);
  assert.equal(plan.actions[1].name, 'repair_pghd_local_only_versions');
  assert.equal(plan.actions[1].eligible, true);
  assert.match(plan.actions[1].command, /20260622145528/);
});

test('buildReconciliationPlan blocks repair when functional checks fail', () => {
  const plan = buildReconciliationPlan({
    functionalOk: false,
    functionalError: 'state smoke failed',
    migrationHistory: {
      ok: true,
      pending: ['20260622145528'],
      missing: [],
      remoteOnlyCount: 0
    }
  });

  assert.equal(plan.ok, false);
  assert.equal(plan.functionalError, 'state smoke failed');
  assert.equal(plan.actions[0].name, 'repair_pghd_local_only_versions');
  assert.equal(plan.actions[0].eligible, false);
});

test('planPghdMigrationReconciliation combines history and functional checks', async () => {
  const calls = [];
  const plan = await planPghdMigrationReconciliation({
    env: { PGHD_SCHEMA_CHECK_RETRIES: '2' },
    migrationHistoryChecker: ({ env }) => {
      calls.push(['history', env]);
      return {
        ok: true,
        pending: [],
        missing: [],
        remoteOnlyCount: 0
      };
    },
    functionalChecker: async ({ env }) => {
      calls.push(['functional', env]);
    }
  });

  assert.equal(plan.ok, true);
  assert.deepEqual(calls, [
    ['history', { PGHD_SCHEMA_CHECK_RETRIES: '2' }],
    ['functional', { PGHD_SCHEMA_CHECK_RETRIES: '2' }]
  ]);
});
