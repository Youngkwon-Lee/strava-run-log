import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import {
  releaseDecisionOutputPath,
  runCommand,
  runPghdReleaseDecision,
  splitCommand,
  writeDecisionRecord
} from '../scripts/run_pghd_release_decision.mjs';
import { REQUIRED_RELEASE_COMMANDS } from '../scripts/report_pghd_release_decision.mjs';

test('splitCommand tokenizes npm commands used by the release runner', () => {
  assert.deepEqual(splitCommand('npm run gate:pghd:release'), ['npm', 'run', 'gate:pghd:release']);
});

test('runCommand returns command status from spawn result', () => {
  const calls = [];
  const result = runCommand('npm run check:pghd:status', {
    stdio: 'pipe',
    env: { NODE_ENV: 'test' },
    spawnFn: (binary, args, options) => {
      calls.push({ binary, args, options });
      return { status: 0, stdout: 'ok', stderr: '' };
    }
  });

  assert.equal(result.ok, true);
  assert.equal(result.stdout, 'ok');
  assert.equal(calls[0].binary, 'npm');
  assert.deepEqual(calls[0].args, ['run', 'check:pghd:status']);
  assert.equal(calls[0].options.env.NODE_ENV, 'test');
});

test('writeDecisionRecord writes the runner result to an ignored output artifact', () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'pghd-decision-'));
  const outputPath = join(tempDir, 'nested', 'decision.json');

  try {
    const writtenPath = writeDecisionRecord(
      { ok: true, decision: { result: 'ready_for_release_review' } },
      { outputPath }
    );

    assert.equal(writtenPath, outputPath);
    const parsed = JSON.parse(readFileSync(outputPath, 'utf8'));
    assert.equal(parsed.ok, true);
    assert.equal(parsed.decision.result, 'ready_for_release_review');
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('releaseDecisionOutputPath uses PGHD_RELEASE_DECISION_OUTPUT override', () => {
  assert.match(
    releaseDecisionOutputPath({ PGHD_RELEASE_DECISION_OUTPUT: 'output/custom-decision.json' }),
    /output\/custom-decision\.json$/
  );
});

test('runPghdReleaseDecision records all successful required commands before decision', async () => {
  const commands = ['npm run first', 'npm run second'];
  const calls = [];
  const result = await runPghdReleaseDecision({
    generatedAt: '2026-06-23T02:00:00.000Z',
    env: {
      PGHD_RELEASE_CANDIDATE: 'rc-runner',
      PGHD_RELEASE_ENVIRONMENT: 'staging'
    },
    commands,
    commandRunner: (command) => {
      calls.push(command);
      return { command, status: 0, ok: true };
    },
    readinessChecker: async ({ env }) => {
      assert.equal(env.PGHD_RELEASE_COMMANDS_RUN, commands.join('\n'));
      return {
        ok: true,
        recommendedApplyPath: 'physio-app-owner-lineage',
        dbPushAllowed: false,
        dbPushBlocked: true,
        ownerBridgeApplied: true,
        localMigrationHistoryOk: false,
        reconciliationFunctionalOk: true,
        reconciliationMissing: [],
        eligibleReconciliationActions: []
      };
    }
  });

  assert.equal(result.ok, true);
  assert.deepEqual(calls, commands);
  assert.deepEqual(result.commandsRun, commands);
  assert.equal(result.failedCommand, null);
  assert.equal(result.decision.candidate, 'rc-runner');
  assert.deepEqual(result.decision.commandsRun, commands);
});

test('runPghdReleaseDecision stops at first failed gate and leaves missing evidence', async () => {
  const commands = REQUIRED_RELEASE_COMMANDS;
  const result = await runPghdReleaseDecision({
    commands,
    commandRunner: (command) => ({
      command,
      status: command === commands[1] ? 1 : 0,
      ok: command !== commands[1]
    }),
    readinessChecker: async () => {
      throw new Error('readiness should not run after a failed gate');
    }
  });

  assert.equal(result.ok, false);
  assert.equal(result.failedCommand, commands[1]);
  assert.deepEqual(result.commandsRun, [commands[0]]);
  assert.deepEqual(result.decision.evidence.missingGateEvidence, commands.slice(1));
  assert.match(result.decision.evidence.blockers[0], /command_failed/);
});
