import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  directSqlApplyToken,
  directSqlSteps,
  requireDirectSqlApplyConfirmation,
  runDirectSqlWorkflow
} from '../scripts/apply_pghd_state_sql_direct.mjs';

test('direct SQL apply workflow requires explicit confirmation token', () => {
  assert.throws(
    () => requireDirectSqlApplyConfirmation({}),
    /PGHD_DIRECT_SQL_APPLY=20260622145528/
  );
  assert.doesNotThrow(() => requireDirectSqlApplyConfirmation({ PGHD_DIRECT_SQL_APPLY: directSqlApplyToken }));
});

test('direct SQL apply workflow steps apply SQL then verify state', () => {
  const steps = directSqlSteps();

  assert.deepEqual(
    steps.map((step) => step.name),
    [
      'apply activity-event state snapshot SQL directly',
      'check state schema readiness',
      'run state DB smoke',
      'run state materialization smoke'
    ]
  );
  assert.deepEqual(steps[0].args, [
    'db',
    'query',
    '--linked',
    '--file',
    'supabase/migrations/20260622145528_add_activity_event_state_snapshots.sql',
    '-o',
    'table'
  ]);
  assert.equal(steps[1].env.PGHD_SCHEMA_CHECK_RETRIES, '10');
});

test('runDirectSqlWorkflow executes steps with supplied env', async () => {
  const names = [];
  const envs = [];
  await runDirectSqlWorkflow({
    env: { PGHD_DIRECT_SQL_APPLY: directSqlApplyToken },
    steps: [{ name: 'one' }, { name: 'two' }],
    runStepFn: async (step, options) => {
      names.push(step.name);
      envs.push(options.env);
    }
  });

  assert.deepEqual(names, ['one', 'two']);
  assert.deepEqual(envs, [
    { PGHD_DIRECT_SQL_APPLY: directSqlApplyToken },
    { PGHD_DIRECT_SQL_APPLY: directSqlApplyToken }
  ]);
});
