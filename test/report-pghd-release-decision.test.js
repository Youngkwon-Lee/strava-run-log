import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildPghdReleaseDecision,
  parseCommandsRun,
  reportPghdReleaseDecision,
  REQUIRED_RELEASE_COMMANDS
} from '../scripts/report_pghd_release_decision.mjs';

test('parseCommandsRun accepts comma and newline separated commands', () => {
  assert.deepEqual(parseCommandsRun('npm test, npm run check:pghd:status\nnpm run smoke:pghd'), [
    'npm test',
    'npm run check:pghd:status',
    'npm run smoke:pghd'
  ]);
});

test('buildPghdReleaseDecision records required gates and owner-lineage residual risk', () => {
  const decision = buildPghdReleaseDecision({
    generatedAt: '2026-06-23T00:00:00.000Z',
    candidate: 'rc-1',
    environment: 'staging',
    commandsRun: REQUIRED_RELEASE_COMMANDS,
    readiness: {
      ok: true,
      recommendedApplyPath: 'physio-app-owner-lineage',
      dbPushAllowed: false,
      dbPushBlocked: true,
      ownerBridgeApplied: true,
      localMigrationHistoryOk: false,
      reconciliationFunctionalOk: true,
      reconciliationMissing: [],
      eligibleReconciliationActions: []
    }
  });

  assert.equal(decision.ok, true);
  assert.equal(decision.candidate, 'rc-1');
  assert.equal(decision.environment, 'staging');
  assert.equal(decision.applyPath, 'physio-app-owner-lineage');
  assert.deepEqual(decision.requiredCommands, REQUIRED_RELEASE_COMMANDS);
  assert.deepEqual(decision.commandsRun, REQUIRED_RELEASE_COMMANDS);
  assert.deepEqual(decision.evidence.missingGateEvidence, []);
  assert.equal(decision.evidence.dbPushAllowed, false);
  assert.equal(decision.evidence.ownerBridgeApplied, true);
  assert.match(decision.residualRisks.join('\n'), /db push remains blocked/);
  assert.doesNotMatch(decision.residualRisks.join('\n'), /full gate output/);
  assert.equal(decision.result, 'ready_for_release_review');
});

test('buildPghdReleaseDecision flags missing full gate evidence separately from readiness', () => {
  const decision = buildPghdReleaseDecision({
    commandsRun: ['npm run gate:pghd:release'],
    readiness: {
      ok: true,
      recommendedApplyPath: 'physio-app-owner-lineage',
      dbPushAllowed: false,
      dbPushBlocked: true,
      ownerBridgeApplied: true,
      localMigrationHistoryOk: false
    }
  });

  assert.equal(decision.ok, true);
  assert.deepEqual(decision.evidence.missingGateEvidence, [
    'npm run gate:pghd:physio-release',
    'npm run gate:pghd:strict-staging',
    'npm run check:pghd:status'
  ]);
  assert.match(decision.residualRisks.join('\n'), /full gate output/);
});

test('buildPghdReleaseDecision carries readiness blockers into next action', () => {
  const decision = buildPghdReleaseDecision({
    readiness: {
      ok: false,
      recommendedApplyPath: 'reconcile-migration-history',
      dbPushAllowed: false,
      dbPushBlocked: true,
      ownerBridgeApplied: false,
      blockers: ['migration_history_not_ok', 'no_verified_apply_path']
    }
  });

  assert.equal(decision.ok, false);
  assert.equal(decision.result, 'not_ready');
  assert.match(decision.residualRisks.join('\n'), /migration_history_not_ok/);
  assert.match(decision.residualRisks.join('\n'), /no_verified_apply_path/);
  assert.match(decision.nextAction, /Fix readiness blockers/);
});

test('reportPghdReleaseDecision uses env labels without mutating release readiness', async () => {
  const calls = [];
  const decision = await reportPghdReleaseDecision({
    generatedAt: '2026-06-23T01:00:00.000Z',
    env: {
      PGHD_RELEASE_CANDIDATE: 'rc-env',
      PGHD_RELEASE_ENVIRONMENT: 'staging',
      PGHD_RELEASE_COMMANDS_RUN: REQUIRED_RELEASE_COMMANDS.join('\n')
    },
    readinessChecker: async ({ env }) => {
      calls.push(env);
      return {
        ok: true,
        recommendedApplyPath: 'run-log-db-push',
        dbPushAllowed: true,
        dbPushBlocked: false,
        ownerBridgeApplied: false,
        localMigrationHistoryOk: true,
        reconciliationFunctionalOk: true,
        reconciliationMissing: [],
        eligibleReconciliationActions: []
      };
    }
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].PGHD_RELEASE_CANDIDATE, 'rc-env');
  assert.equal(decision.candidate, 'rc-env');
  assert.equal(decision.environment, 'staging');
  assert.equal(decision.applyPath, 'run-log-db-push');
  assert.deepEqual(decision.commandsRun, REQUIRED_RELEASE_COMMANDS);
  assert.deepEqual(decision.residualRisks, []);
});
