#!/usr/bin/env node

import { pathToFileURL } from 'node:url';
import { checkPghdReleaseReadiness } from './check_pghd_release_readiness.mjs';

export const REQUIRED_RELEASE_COMMANDS = [
  'npm run gate:pghd:release',
  'npm run gate:pghd:physio-release',
  'npm run gate:pghd:strict-staging',
  'npm run check:pghd:status'
];

export function parseCommandsRun(value = '') {
  return String(value)
    .split(/\r?\n|,/)
    .map((item) => item.trim())
    .filter(Boolean);
}

export function buildPghdReleaseDecision({
  readiness,
  candidate = 'working-tree',
  environment = 'local',
  generatedAt = new Date().toISOString(),
  commandsRun = []
} = {}) {
  const blockers = readiness?.blockers || [];
  const residualRisks = [];
  const normalizedCommandsRun = commandsRun.map((command) => String(command).trim()).filter(Boolean);
  const missingGateEvidence = REQUIRED_RELEASE_COMMANDS.filter(
    (command) => !normalizedCommandsRun.includes(command)
  );

  if (readiness?.dbPushBlocked && !readiness?.dbPushAllowed) {
    residualRisks.push('broad run-log Supabase db push remains blocked; use the accepted owner-lineage apply path');
  }
  if (missingGateEvidence.length > 0) {
    residualRisks.push('full gate output has not been attached for every required release command');
  }
  if (!readiness?.ownerBridgeApplied && readiness?.recommendedApplyPath === 'physio-app-owner-lineage') {
    residualRisks.push('owner-lineage bridge is not proven applied');
  }
  for (const blocker of blockers) {
    residualRisks.push(`release readiness blocker: ${blocker}`);
  }

  const result = readiness?.ok ? 'ready_for_release_review' : 'not_ready';
  const nextAction = readiness?.ok
    ? 'Attach full gate output for the required commands before approving a release.'
    : 'Fix readiness blockers, then rerun npm run check:pghd:release-readiness and this decision report.';

  return {
    ok: Boolean(readiness?.ok),
    candidate,
    date: generatedAt,
    environment,
    applyPath: readiness?.recommendedApplyPath || 'unknown',
    requiredCommands: REQUIRED_RELEASE_COMMANDS,
    commandsRun: normalizedCommandsRun,
    evidence: {
      readinessOk: Boolean(readiness?.ok),
      dbPushAllowed: Boolean(readiness?.dbPushAllowed),
      dbPushBlocked: Boolean(readiness?.dbPushBlocked),
      ownerBridgeApplied: Boolean(readiness?.ownerBridgeApplied),
      localMigrationHistoryOk: Boolean(readiness?.localMigrationHistoryOk),
      reconciliationFunctionalOk: Boolean(readiness?.reconciliationFunctionalOk),
      reconciliationMissing: readiness?.reconciliationMissing || [],
      eligibleReconciliationActions: readiness?.eligibleReconciliationActions || [],
      missingGateEvidence,
      blockers
    },
    result,
    residualRisks,
    nextAction
  };
}

export async function reportPghdReleaseDecision({
  env = process.env,
  readinessChecker = checkPghdReleaseReadiness,
  generatedAt
} = {}) {
  const readiness = await readinessChecker({ env });
  return buildPghdReleaseDecision({
    readiness,
    candidate: env.PGHD_RELEASE_CANDIDATE || 'working-tree',
    environment: env.PGHD_RELEASE_ENVIRONMENT || 'local',
    generatedAt,
    commandsRun: parseCommandsRun(env.PGHD_RELEASE_COMMANDS_RUN)
  });
}

async function main() {
  const decision = await reportPghdReleaseDecision();
  console.log(JSON.stringify(decision, null, 2));
  if (!decision.ok) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exit(1);
  });
}
