#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  buildPghdReleaseDecision,
  REQUIRED_RELEASE_COMMANDS
} from './report_pghd_release_decision.mjs';
import { checkPghdReleaseReadiness } from './check_pghd_release_readiness.mjs';

export function splitCommand(command) {
  return String(command || '').trim().split(/\s+/).filter(Boolean);
}

export function runCommand(command, {
  env = process.env,
  spawnFn = spawnSync,
  stdio = 'inherit'
} = {}) {
  const [binary, ...args] = splitCommand(command);
  if (!binary) throw new Error('cannot run an empty PGHD release command');
  const result = spawnFn(binary, args, {
    env,
    stdio,
    encoding: stdio === 'pipe' ? 'utf8' : undefined
  });
  if (result.error) throw result.error;
  return {
    command,
    status: result.status ?? 0,
    ok: result.status === 0,
    stdout: result.stdout || '',
    stderr: result.stderr || ''
  };
}

export function releaseDecisionOutputPath(env = process.env) {
  return resolve(env.PGHD_RELEASE_DECISION_OUTPUT || 'output/pghd-release-decision/latest.json');
}

export function writeDecisionRecord(result, {
  env = process.env,
  outputPath = releaseDecisionOutputPath(env)
} = {}) {
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(result, null, 2)}\n`);
  return outputPath;
}

export async function runPghdReleaseDecision({
  env = process.env,
  commands = REQUIRED_RELEASE_COMMANDS,
  commandRunner = runCommand,
  readinessChecker = checkPghdReleaseReadiness,
  generatedAt
} = {}) {
  const commandsRun = [];
  const commandResults = [];

  for (const command of commands) {
    const result = commandRunner(command, { env });
    commandResults.push(result);
    if (!result.ok) {
      return {
        ok: false,
        failedCommand: command,
        commandsRun,
        commandResults,
        decision: buildPghdReleaseDecision({
          readiness: {
            ok: false,
            recommendedApplyPath: 'unknown',
            blockers: [`command_failed:${command}`]
          },
          candidate: env.PGHD_RELEASE_CANDIDATE || 'working-tree',
          environment: env.PGHD_RELEASE_ENVIRONMENT || 'local',
          generatedAt,
          commandsRun
        })
      };
    }
    commandsRun.push(command);
  }

  const readiness = await readinessChecker({
    env: {
      ...env,
      PGHD_RELEASE_COMMANDS_RUN: commandsRun.join('\n')
    }
  });
  return {
    ok: Boolean(readiness.ok),
    failedCommand: null,
    commandsRun,
    commandResults,
    decision: buildPghdReleaseDecision({
      readiness,
      candidate: env.PGHD_RELEASE_CANDIDATE || 'working-tree',
      environment: env.PGHD_RELEASE_ENVIRONMENT || 'local',
      generatedAt,
      commandsRun
    })
  };
}

async function main() {
  const result = await runPghdReleaseDecision();
  const outputPath = writeDecisionRecord(result);
  console.log(JSON.stringify(result, null, 2));
  console.error(`PGHD release decision record written to ${outputPath}`);
  if (!result.ok || !result.decision?.ok) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exit(1);
  });
}
