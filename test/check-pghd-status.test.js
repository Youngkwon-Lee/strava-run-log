import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildPghdStatus,
  checkPghdPreflightSurface,
  classifyPghdApplyPath
} from '../scripts/check_pghd_status.mjs';

test('classifyPghdApplyPath allows run-log db push only when local history is clean', () => {
  assert.deepEqual(
    classifyPghdApplyPath({ localMigrationHistoryOk: true, dbPushBlocked: false }),
    {
      dbPushAllowed: true,
      recommendedApplyPath: 'run-log-db-push',
      applyPathMessage: 'Local migration history is reconciled; run-log Supabase db push is allowed after normal review.'
    }
  );

  assert.deepEqual(
    classifyPghdApplyPath({ localMigrationHistoryOk: false, ownerBridgeApplied: true, dbPushBlocked: true }),
    {
      dbPushAllowed: false,
      recommendedApplyPath: 'physio-app-owner-lineage',
      applyPathMessage: 'Use the PhysioApp owner-lineage bridge path; broad run-log Supabase db push remains blocked.'
    }
  );

  assert.deepEqual(
    classifyPghdApplyPath({ localMigrationHistoryOk: false, ownerBridgeApplied: false, dbPushBlocked: true }),
    {
      dbPushAllowed: false,
      recommendedApplyPath: 'reconcile-migration-history',
      applyPathMessage: 'Reconcile linked Supabase migration history before applying migrations from this repo.'
    }
  );
});

test('buildPghdStatus reports full success when functional and migration history pass', async () => {
  const status = await buildPghdStatus({
    migrationHistoryChecker: () => ({ ok: true, localMigrationHistoryOk: true, dbPushBlocked: false }),
    functionalChecker: async () => {}
  });

  assert.equal(status.ok, true);
  assert.equal(status.preflightSurfaceOk, true);
  assert.equal(status.functionalOk, true);
  assert.equal(status.migrationHistoryOk, true);
  assert.equal(status.localMigrationHistoryOk, true);
  assert.equal(status.dbPushBlocked, false);
  assert.equal(status.dbPushAllowed, true);
  assert.equal(status.recommendedApplyPath, 'run-log-db-push');
});

test('checkPghdPreflightSurface covers strict staging and cleanup contracts', () => {
  const surface = checkPghdPreflightSurface();
  const names = surface.checks.map((check) => check.name);

  assert.equal(surface.ok, true);
  assert.ok(names.includes('strict staging smoke gates are exposed'));
  assert.ok(names.includes('smoke cleanup checker covers PGHD artifacts'));
});

test('buildPghdStatus separates functional success from blocked migration history', async () => {
  const status = await buildPghdStatus({
    migrationHistoryChecker: () => ({ ok: false, dbPushBlocked: true, remoteOnlyCount: 337 }),
    functionalChecker: async () => {}
  });

  assert.equal(status.ok, false);
  assert.equal(status.preflightSurfaceOk, true);
  assert.equal(status.functionalOk, true);
  assert.equal(status.migrationHistoryOk, false);
  assert.equal(status.dbPushBlocked, true);
  assert.equal(status.migrationHistory.remoteOnlyCount, 337);
  assert.equal(status.dbPushAllowed, false);
  assert.equal(status.recommendedApplyPath, 'reconcile-migration-history');
});

test('buildPghdStatus reports owner bridge success separately from local db push blocker', async () => {
  const status = await buildPghdStatus({
    migrationHistoryChecker: () => ({
      ok: true,
      localMigrationHistoryOk: false,
      ownerBridgeApplied: true,
      dbPushBlocked: true
    }),
    functionalChecker: async () => {}
  });

  assert.equal(status.ok, true);
  assert.equal(status.preflightSurfaceOk, true);
  assert.equal(status.functionalOk, true);
  assert.equal(status.migrationHistoryOk, true);
  assert.equal(status.localMigrationHistoryOk, false);
  assert.equal(status.ownerBridgeApplied, true);
  assert.equal(status.dbPushBlocked, true);
  assert.equal(status.dbPushAllowed, false);
  assert.equal(status.recommendedApplyPath, 'physio-app-owner-lineage');
});

test('buildPghdStatus reports functional failure independently', async () => {
  const status = await buildPghdStatus({
    migrationHistoryChecker: () => ({ ok: true, dbPushBlocked: false }),
    functionalChecker: async () => {
      throw new Error('state smoke failed');
    }
  });

  assert.equal(status.ok, false);
  assert.equal(status.preflightSurfaceOk, true);
  assert.equal(status.functionalOk, false);
  assert.equal(status.migrationHistoryOk, true);
  assert.match(status.functional.error, /state smoke failed/);
});

test('buildPghdStatus blocks success when preflight surface coverage is missing', async () => {
  const status = await buildPghdStatus({
    preflightSurfaceChecker: () => ({
      ok: false,
      checks: [
        { name: 'preflight endpoint file', ok: true },
        { name: 'E2E smoke verifies preflight', ok: false }
      ]
    }),
    migrationHistoryChecker: () => ({ ok: true, dbPushBlocked: false }),
    functionalChecker: async () => {}
  });

  assert.equal(status.ok, false);
  assert.equal(status.preflightSurfaceOk, false);
  assert.equal(status.functionalOk, true);
  assert.equal(status.migrationHistoryOk, true);
  assert.equal(status.preflightSurface.checks[1].ok, false);
});
