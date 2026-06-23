import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { test } from 'node:test';
import {
  requireDbPushReady,
  requireRemoteDbPassword,
  runStep,
  runWorkflow,
  workflowSteps
} from '../scripts/apply_pghd_state_migration.mjs';

test('PGHD state migration workflow requires remote DB password', async () => {
  assert.throws(
    () => requireRemoteDbPassword({}),
    /missing SUPABASE_DB_PASSWORD/
  );
  assert.doesNotThrow(() => requireRemoteDbPassword({ SUPABASE_DB_PASSWORD: 'secret' }));
});

test('PGHD state migration workflow blocks db push when linked history is not reconciled', () => {
  assert.throws(
    () => requireDbPushReady({
      dbPushBlocked: true,
      pending: ['20260622145528'],
      missing: [],
      nextActions: [{ command: 'supabase migration fetch --linked' }]
    }),
    /dbPushBlocked=true.*pending=20260622145528.*supabase migration fetch --linked/
  );

  assert.doesNotThrow(() =>
    requireDbPushReady({
      dbPushBlocked: false,
      pending: [],
      missing: []
    })
  );
});

test('PGHD state migration workflow steps are ordered and set schema retry default', () => {
  const steps = workflowSteps({});

  assert.deepEqual(
    steps.map((step) => step.name),
    [
      'check required migration history',
      'list migrations before push',
      'push pending Supabase migrations',
      'list migrations after push',
      'check state schema readiness',
      'run state DB smoke',
      'run state materialization smoke'
    ]
  );
  assert.deepEqual(steps[0].args, ['run', 'check:pghd:migration-history']);
  assert.deepEqual(steps[1].args, ['migration', 'list', '--linked']);
  assert.equal(steps[1].requiresDbPushReady, true);
  assert.deepEqual(steps[2].args, ['db', 'push', '--linked', '--yes']);
  assert.equal(steps[2].requiresRemoteDbPassword, true);
  assert.deepEqual(steps[3].args, ['migration', 'list', '--linked']);
  assert.equal(steps[4].env.PGHD_SCHEMA_CHECK_RETRIES, '10');
});

test('PGHD state migration workflow preserves explicit schema retry setting', () => {
  const steps = workflowSteps({ PGHD_SCHEMA_CHECK_RETRIES: '4' });
  assert.equal(steps[4].env.PGHD_SCHEMA_CHECK_RETRIES, '4');
});

test('runStep passes merged env and resolves on zero exit', async () => {
  const spawned = [];
  await runStep(
    {
      name: 'test step',
      command: 'npm',
      args: ['run', 'example'],
      env: { PGHD_SCHEMA_CHECK_RETRIES: '3' }
    },
    {
      env: { SUPABASE_DB_PASSWORD: 'secret' },
      log: () => {},
      spawnFn: (command, args, options) => {
        spawned.push({ command, args, options });
        const child = new EventEmitter();
        queueMicrotask(() => child.emit('close', 0));
        return child;
      }
    }
  );

  assert.equal(spawned[0].command, 'npm');
  assert.deepEqual(spawned[0].args, ['run', 'example']);
  assert.equal(spawned[0].options.env.SUPABASE_DB_PASSWORD, 'secret');
  assert.equal(spawned[0].options.env.PGHD_SCHEMA_CHECK_RETRIES, '3');
});

test('runWorkflow executes steps in order', async () => {
  const names = [];
  const envs = [];
  await runWorkflow({
    env: { SUPABASE_DB_PASSWORD: 'secret' },
    steps: [{ name: 'one' }, { name: 'two' }],
    runStepFn: async (step, options) => {
      names.push(step.name);
      envs.push(options.env);
    }
  });

  assert.deepEqual(names, ['one', 'two']);
  assert.deepEqual(envs, [{ SUPABASE_DB_PASSWORD: 'secret' }, { SUPABASE_DB_PASSWORD: 'secret' }]);
});

test('runWorkflow runs preflight steps before checking push readiness', async () => {
  const names = [];
  await assert.rejects(
    () =>
      runWorkflow({
        env: {},
        steps: [
          { name: 'preflight one' },
          { name: 'list', requiresDbPushReady: true },
          { name: 'push', requiresRemoteDbPassword: true }
        ],
        runStepFn: async (step) => names.push(step.name),
        migrationHistoryChecker: () => ({
          dbPushBlocked: true,
          pending: ['20260622145528'],
          missing: []
        })
      }),
    /linked Supabase migration history is not ready for db push/
  );

  assert.deepEqual(names, ['preflight one']);
});

test('runWorkflow checks migration history before requiring remote DB password', async () => {
  await assert.rejects(
    () =>
      runWorkflow({
        env: {},
        steps: [{ name: 'push', requiresRemoteDbPassword: true }],
        runStepFn: async () => {},
        migrationHistoryChecker: () => ({
          dbPushBlocked: true,
          pending: [],
          missing: []
        })
      }),
    /linked Supabase migration history is not ready for db push/
  );
});
