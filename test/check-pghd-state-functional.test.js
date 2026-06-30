import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  functionalCheckSteps,
  runFunctionalChecks
} from '../scripts/check_pghd_state_functional.mjs';

test('functional state checks run schema and state smokes in order', () => {
  const steps = functionalCheckSteps({});

  assert.deepEqual(
    steps.map((step) => step.name),
    [
      'check state schema readiness',
      'run state DB smoke',
      'run state materialization smoke'
    ]
  );
  assert.deepEqual(steps[0].args, ['run', 'check:pghd:state-schema']);
  assert.equal(steps[0].env.PGHD_SCHEMA_CHECK_RETRIES, '3');
});

test('functional state checks preserve explicit schema retry setting', () => {
  const steps = functionalCheckSteps({ PGHD_SCHEMA_CHECK_RETRIES: '8' });
  assert.equal(steps[0].env.PGHD_SCHEMA_CHECK_RETRIES, '8');
});

test('runFunctionalChecks executes steps with supplied env', async () => {
  const names = [];
  const envs = [];

  await runFunctionalChecks({
    env: { PGHD_SCHEMA_CHECK_RETRIES: '2' },
    steps: [{ name: 'one' }, { name: 'two' }],
    runStepFn: async (step, options) => {
      names.push(step.name);
      envs.push(options.env);
    }
  });

  assert.deepEqual(names, ['one', 'two']);
  assert.deepEqual(envs, [{ PGHD_SCHEMA_CHECK_RETRIES: '2' }, { PGHD_SCHEMA_CHECK_RETRIES: '2' }]);
});
