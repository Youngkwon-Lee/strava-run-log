import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildMigrationHistoryNextActions,
  checkRequiredMigrationHistory,
  migrationListTimeoutMs,
  parseMigrationList,
  summarizeRequiredMigrations
} from '../scripts/check_pghd_migration_history.mjs';

test('migrationListTimeoutMs bounds timeout env value', () => {
  assert.equal(migrationListTimeoutMs({ PGHD_MIGRATION_LIST_TIMEOUT_MS: '1' }), 5000);
  assert.equal(migrationListTimeoutMs({ PGHD_MIGRATION_LIST_TIMEOUT_MS: '45000' }), 45000);
  assert.equal(migrationListTimeoutMs({ PGHD_MIGRATION_LIST_TIMEOUT_MS: '999999' }), 120000);
  assert.equal(migrationListTimeoutMs({ PGHD_MIGRATION_LIST_TIMEOUT_MS: 'bad' }), 60000);
  assert.equal(migrationListTimeoutMs({}), 60000);
});

test('parseMigrationList reads local-only and remote-only rows', () => {
  const rows = parseMigrationList(`
   Local          | Remote         | Time (UTC)
  ----------------|----------------|---------------------
                  | 20260621033128 | 2026-06-21 03:31:28
   20260622014705 |                | 2026-06-22 01:47:05
   20260622145528 |                | 2026-06-22 14:55:28
`);

  assert.deepEqual(rows, [
    { local: null, remote: '20260621033128' },
    { local: '20260622014705', remote: null },
    { local: '20260622145528', remote: null }
  ]);
});

test('summarizeRequiredMigrations classifies required migration status', () => {
  const summary = summarizeRequiredMigrations(
    [
      { local: '20260622014705', remote: '20260622014705' },
      { local: '20260622023954', remote: null },
      { local: null, remote: '20260622040100' }
    ],
    ['20260622014705', '20260622023954', '20260622040100', '20260622043000']
  );

  assert.deepEqual(summary.map((item) => item.status), ['applied', 'pending', 'remote-only', 'missing']);
});

test('checkRequiredMigrationHistory reports pending required migrations as local history debt', () => {
  const result = checkRequiredMigrationHistory({
    listOutput: `
   20260622014705 |                | 2026-06-22 01:47:05
   20260622023954 |                | 2026-06-22 02:39:54
   20260622040100 |                | 2026-06-22 04:01:00
   20260622043000 |                | 2026-06-22 04:30:00
   20260622145528 |                | 2026-06-22 14:55:28
`
  });

  assert.equal(result.ok, false);
  assert.equal(result.localMigrationHistoryOk, false);
  assert.deepEqual(result.pending, [
    '20260622014705',
    '20260622023954',
    '20260622040100',
    '20260622043000',
    '20260622145528'
  ]);
  assert.equal(result.dbPushBlocked, false);
  assert.match(result.nextActions[0].command, /supabase migration repair/);
});

test('checkRequiredMigrationHistory passes timeout env to migration list command', () => {
  const calls = [];
  const result = checkRequiredMigrationHistory({
    env: { PGHD_MIGRATION_LIST_TIMEOUT_MS: '7000' },
    spawnFn: (command, args, options) => {
      calls.push({ command, args, options });
      return {
        status: 0,
        stdout: '   20260622014705 |                | 2026-06-22 01:47:05\n',
        stderr: ''
      };
    }
  });

  assert.equal(calls[0].command, 'supabase');
  assert.deepEqual(calls[0].args, ['migration', 'list', '--linked']);
  assert.equal(calls[0].options.timeout, 7000);
  assert.equal(result.pending.includes('20260622014705'), true);
});

test('checkRequiredMigrationHistory blocks db push when remote-only migrations exist', () => {
  const result = checkRequiredMigrationHistory({
    listOutput: `
                  | 20260621033128 | 2026-06-21 03:31:28
   20260622014705 |                | 2026-06-22 01:47:05
   20260622023954 |                | 2026-06-22 02:39:54
   20260622040100 |                | 2026-06-22 04:01:00
   20260622043000 |                | 2026-06-22 04:30:00
   20260622145528 |                | 2026-06-22 14:55:28
`
  });

  assert.equal(result.ok, false);
  assert.equal(result.localMigrationHistoryOk, false);
  assert.equal(result.ownerBridgeApplied, false);
  assert.equal(result.dbPushBlocked, true);
  assert.equal(result.remoteOnlyCount, 1);
  assert.deepEqual(result.remoteOnlySample, ['20260621033128']);
  assert.equal(result.nextActions[0].command, 'supabase migration fetch --linked');
  assert.match(result.nextActions[1].command, /supabase migration repair/);
});

test('checkRequiredMigrationHistory accepts applied PhysioApp owner bridge despite local db push blocker', () => {
  const result = checkRequiredMigrationHistory({
    listOutput: `
                  | 20260215234342 | 2026-02-15 23:43:42
                  | 20260622162503 | 2026-06-22 16:25:03
   20260622014705 |                | 2026-06-22 01:47:05
   20260622023954 |                | 2026-06-22 02:39:54
   20260622040100 |                | 2026-06-22 04:01:00
   20260622043000 |                | 2026-06-22 04:30:00
   20260622145528 |                | 2026-06-22 14:55:28
`
  });

  assert.equal(result.ok, true);
  assert.equal(result.localMigrationHistoryOk, false);
  assert.equal(result.ownerBridgeApplied, true);
  assert.equal(result.dbPushBlocked, true);
  assert.equal(result.nextActions.length, 2);
});

test('buildMigrationHistoryNextActions recommends fetch before repair', () => {
  const actions = buildMigrationHistoryNextActions({
    remoteOnlyCount: 2,
    pending: ['20260622014705', '20260622145528'],
    missing: []
  });

  assert.equal(actions[0].command, 'supabase migration fetch --linked');
  assert.equal(
    actions[1].command,
    'supabase migration repair 20260622014705 20260622145528 --status applied --linked'
  );
});
