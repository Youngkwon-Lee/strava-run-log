import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  assertReconciliationPlanExecutable,
  buildReconciliationApplySteps,
  reconciliationApplyToken,
  requireReconciliationApplyConfirmation,
  runReconciliationApplyWorkflow
} from '../scripts/apply_pghd_migration_reconciliation.mjs';

test('PGHD migration reconciliation requires explicit confirmation token', () => {
  assert.throws(
    () => requireReconciliationApplyConfirmation({}),
    /PGHD_MIGRATION_RECONCILE_APPLY=20260622145528/
  );
  assert.doesNotThrow(() =>
    requireReconciliationApplyConfirmation({
      PGHD_MIGRATION_RECONCILE_APPLY: reconciliationApplyToken
    })
  );
});

test('buildReconciliationApplySteps fetches before focused PGHD repair', () => {
  const steps = buildReconciliationApplySteps({
    pending: ['20260622014705', '20260622145528'],
    actions: [
      { name: 'fetch_remote_history', eligible: true },
      { name: 'repair_pghd_local_only_versions', eligible: true }
    ]
  });

  assert.deepEqual(steps.map((step) => step.name), [
    'fetch linked remote migration history',
    'mark PGHD local-only migrations applied',
    'verify PGHD release readiness after reconciliation'
  ]);
  assert.deepEqual(steps[0].args, ['migration', 'fetch', '--linked']);
  assert.deepEqual(steps[1].args, [
    'migration',
    'repair',
    '20260622014705',
    '20260622145528',
    '--status',
    'applied',
    '--linked'
  ]);
  assert.deepEqual(steps[2].args, ['run', 'check:pghd:release-readiness']);
});

test('assertReconciliationPlanExecutable blocks missing or unproven plans', () => {
  assert.throws(
    () => assertReconciliationPlanExecutable({ functionalOk: false, functionalError: 'state failed' }),
    /state failed/
  );
  assert.throws(
    () => assertReconciliationPlanExecutable({ functionalOk: true, missing: ['20260622145528'] }),
    /required PGHD migrations are missing/
  );
  assert.throws(
    () =>
      assertReconciliationPlanExecutable({
        functionalOk: true,
        missing: [],
        actions: [{ name: 'repair_pghd_local_only_versions', eligible: false }]
      }),
    /repair action is not eligible/
  );
});

test('runReconciliationApplyWorkflow executes only after token and green plan', async () => {
  const calls = [];
  await runReconciliationApplyWorkflow({
    env: { PGHD_MIGRATION_RECONCILE_APPLY: reconciliationApplyToken },
    planner: async ({ env }) => {
      calls.push(['planner', env]);
      return {
        functionalOk: true,
        localMigrationHistoryOk: false,
        ownerBridgeApplied: true,
        dbPushBlocked: true,
        pending: ['20260622145528'],
        missing: [],
        actions: [
          { name: 'fetch_remote_history', eligible: true },
          { name: 'repair_pghd_local_only_versions', eligible: true }
        ]
      };
    },
    runStepFn: async (step, { env }) => {
      calls.push([step.name, step.args, env]);
    }
  });

  assert.equal(calls[0][0], 'planner');
  assert.deepEqual(calls.slice(1).map((call) => call[0]), [
    'fetch linked remote migration history',
    'mark PGHD local-only migrations applied',
    'verify PGHD release readiness after reconciliation'
  ]);
});
