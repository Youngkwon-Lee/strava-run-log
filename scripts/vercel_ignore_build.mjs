#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const BUILD_RELEVANT_PREFIXES = [
  'api/',
  'lib/',
  'public/'
];

const BUILD_RELEVANT_FILES = new Set([
  '.vercelignore',
  'index.html',
  'package.json',
  'package-lock.json',
  'npm-shrinkwrap.json',
  'settings.html',
  'vercel.json',
  'scripts/vercel_ignore_build.mjs'
]);

function normalizePath(path) {
  return String(path || '').replace(/\\/g, '/').replace(/^\.\/+/, '');
}

export function isVercelBuildRelevantPath(path) {
  const normalized = normalizePath(path);
  return BUILD_RELEVANT_FILES.has(normalized)
    || BUILD_RELEVANT_PREFIXES.some((prefix) => normalized.startsWith(prefix));
}

export function buildVercelIgnoreDecision(changedFiles) {
  const normalizedFiles = [...new Set((changedFiles || []).map(normalizePath).filter(Boolean))].sort();
  const buildRelevantFiles = normalizedFiles.filter(isVercelBuildRelevantPath);

  return {
    changedFiles: normalizedFiles,
    buildRelevantFiles,
    shouldIgnore: normalizedFiles.length > 0 && buildRelevantFiles.length === 0
  };
}

function gitDiffNames(args, cwd) {
  const result = spawnSync('git', ['diff', '--name-only', '--diff-filter=ACMRT', ...args], {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  });

  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || 'git diff failed').trim());
  }

  return result.stdout.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
}

export function readChangedFiles({ cwd = process.cwd(), env = process.env } = {}) {
  const previousSha = String(env.VERCEL_GIT_PREVIOUS_SHA || '').trim();
  if (previousSha && !/^0+$/.test(previousSha)) {
    return gitDiffNames([previousSha, 'HEAD'], cwd);
  }

  return gitDiffNames(['HEAD^', 'HEAD'], cwd);
}

function main() {
  let decision;
  try {
    decision = buildVercelIgnoreDecision(readChangedFiles());
  } catch (error) {
    console.log(`Vercel ignore build: changed files could not be determined; continuing build. ${error.message}`);
    process.exit(1);
  }

  if (decision.shouldIgnore) {
    console.log(`Vercel ignore build: skipping preview build; changed files are not deployment-relevant (${decision.changedFiles.join(', ')}).`);
    process.exit(0);
  }

  console.log(`Vercel ignore build: continuing build; deployment-relevant files changed (${decision.buildRelevantFiles.join(', ') || 'none detected'}).`);
  process.exit(1);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
