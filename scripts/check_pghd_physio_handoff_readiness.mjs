#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

export const DEFAULT_PHYSIO_APP_DIR = '/Users/youngkwon/Projects/physio_app';

const PHYSIO_HANDOFF_SURFACE = [
  {
    name: 'configured import route',
    file: 'src/app/api/app/encounters/[encounterId]/pghd-note-draft/import/route.ts',
    includes: [
      'resolvePghdRunLogImportConfig',
      'fetchPghdNoteDraftExportFromRunLog',
      'NOTE_WRITE_ROLES',
      'requireCustomHeader',
    ],
  },
  {
    name: 'run-log note draft client',
    file: 'src/features/encounter-room/lib/pghd-note-draft-client.ts',
    includes: [
      '/api/run-log/preflight',
      '/api/run-log/encounter-insights',
      '/api/run-log/encounter-note-drafts',
      '/pghd-note-draft/import',
      'runLogPreflight',
    ],
  },
  {
    name: 'server import config',
    file: 'src/features/encounter-room/server/pghd-run-log-import-config.ts',
    includes: [
      'TOKEN_ENV_ALLOWLIST',
      'PGHD_RUN_LOG_TOKEN',
      'RUN_LOG_ADMIN_TOKEN',
      'LIVE_METRICS_TOKEN',
      'pghd_run_log_bridge',
    ],
  },
  {
    name: 'encounter import panel',
    file: 'src/features/encounter-room/components/pghd-note-draft-import-panel.tsx',
    includes: [
      'fetchPghdNoteDraftExportFromConfiguredRunLog',
      'configuredRunLogImport',
      'Configured run-log source filter',
      'Run-log preflight readiness',
    ],
  },
  {
    name: 'configured import e2e',
    file: 'e2e/pghd-note-draft-handoff.verify.spec.ts',
    includes: [
      'imports and saves a configured run-log draft through the server proxy',
      'E2E_PGHD_RUN_LOG_FIXTURE',
      'Fixture PGHD run-log note draft',
    ],
  },
];

function parseArgs(argv = process.argv.slice(2)) {
  return {
    json: argv.includes('--json'),
    staticOnly: argv.includes('--static-only'),
    physioAppDir: process.env.PHYSIO_APP_DIR || DEFAULT_PHYSIO_APP_DIR,
  };
}

function checkFileIncludes(rootDir, surface) {
  const absolutePath = path.join(rootDir, surface.file);
  if (!existsSync(absolutePath)) {
    return {
      name: surface.name,
      ok: false,
      file: surface.file,
      missing: ['file'],
    };
  }

  const source = readFileSync(absolutePath, 'utf8');
  const missing = surface.includes.filter((expected) => !source.includes(expected));
  return {
    name: surface.name,
    ok: missing.length === 0,
    file: surface.file,
    missing,
  };
}

export function checkPhysioHandoffSurface(physioAppDir) {
  return PHYSIO_HANDOFF_SURFACE.map((surface) => checkFileIncludes(physioAppDir, surface));
}

function runCommand({ name, cwd, command, args }) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd,
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.on('error', (error) => {
      resolve({
        name,
        ok: false,
        command: [command, ...args].join(' '),
        cwd,
        error: error.message,
      });
    });
    child.on('close', (code) => {
      resolve({
        name,
        ok: code === 0,
        command: [command, ...args].join(' '),
        cwd,
        exitCode: code,
        stdout: stdout.trim().slice(-4000),
        stderr: stderr.trim().slice(-4000),
      });
    });
  });
}

export async function buildPghdPhysioHandoffReadiness(options = {}) {
  const runLogDir = options.runLogDir || process.cwd();
  const physioAppDir = options.physioAppDir || process.env.PHYSIO_APP_DIR || DEFAULT_PHYSIO_APP_DIR;
  const staticOnly = Boolean(options.staticOnly);

  const checks = [
    {
      name: 'physio app directory',
      ok: existsSync(physioAppDir),
      path: physioAppDir,
    },
    ...checkPhysioHandoffSurface(physioAppDir),
  ];

  if (!staticOnly) {
    checks.push(
      await runCommand({
        name: 'run-log PGHD release readiness',
        cwd: runLogDir,
        command: 'npm',
        args: ['run', 'check:pghd:release-readiness'],
      }),
    );

    if (existsSync(physioAppDir)) {
      checks.push(
        await runCommand({
          name: 'PhysioApp production readiness',
          cwd: physioAppDir,
          command: 'pnpm',
          args: ['run', 'check:production-readiness'],
        }),
        await runCommand({
          name: 'PhysioApp ops readiness',
          cwd: physioAppDir,
          command: 'pnpm',
          args: ['run', 'check:ops-readiness'],
        }),
      );
    }
  }

  const failures = checks.filter((check) => !check.ok);
  return {
    ok: failures.length === 0,
    source: 'pghd-physio-handoff-readiness',
    physioAppDir,
    staticOnly,
    checks,
    failures,
  };
}

function printHuman(report) {
  for (const check of report.checks) {
    const status = check.ok ? 'ok' : 'fail';
    console.log(`${status}\t${check.name}`);
    if (!check.ok && check.missing?.length) {
      console.log(`  missing: ${check.missing.join(', ')}`);
    }
    if (!check.ok && check.error) {
      console.log(`  error: ${check.error}`);
    }
  }
  console.log(report.ok ? 'PGHD Physio handoff readiness passed.' : 'PGHD Physio handoff readiness failed.');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = parseArgs();
  const report = await buildPghdPhysioHandoffReadiness(args);

  if (args.json) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    printHuman(report);
  }

  if (!report.ok) process.exitCode = 1;
}
