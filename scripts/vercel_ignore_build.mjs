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

function githubPullFilesUrl(env) {
  const owner = String(env.VERCEL_GIT_REPO_OWNER || '').trim();
  const repo = String(env.VERCEL_GIT_REPO_SLUG || '').trim();
  const pullRequestId = String(env.VERCEL_GIT_PULL_REQUEST_ID || '').trim();

  if (!owner || !repo || !pullRequestId) {
    return null;
  }

  return `https://api.github.com/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/pulls/${encodeURIComponent(pullRequestId)}/files?per_page=100`;
}

async function readGitHubPullFiles({ env, fetchImpl }) {
  const url = githubPullFilesUrl(env);
  if (!url) {
    return null;
  }

  if (typeof fetchImpl !== 'function') {
    throw new Error('fetch is not available for GitHub pull request file lookup');
  }

  const response = await fetchImpl(url, {
    headers: {
      accept: 'application/vnd.github+json',
      'user-agent': 'strava-run-log-vercel-ignore-build'
    }
  });

  if (!response.ok) {
    throw new Error(`GitHub pull request file lookup failed with ${response.status}`);
  }

  const files = await response.json();
  return files.map((file) => file.filename).filter(Boolean);
}

export async function readChangedFiles({
  cwd = process.cwd(),
  env = process.env,
  fetchImpl = globalThis.fetch
} = {}) {
  const gitErrors = [];
  const pullFiles = await readGitHubPullFiles({ env, fetchImpl });
  if (pullFiles) {
    return pullFiles;
  }

  const previousSha = String(env.VERCEL_GIT_PREVIOUS_SHA || '').trim();
  if (previousSha && !/^0+$/.test(previousSha)) {
    try {
      return gitDiffNames([previousSha, 'HEAD'], cwd);
    } catch (error) {
      gitErrors.push(error.message);
    }
  }

  try {
    return gitDiffNames(['HEAD^', 'HEAD'], cwd);
  } catch (error) {
    gitErrors.push(error.message);
    throw new Error(gitErrors.join('; '));
  }
}

async function main() {
  let decision;
  try {
    decision = buildVercelIgnoreDecision(await readChangedFiles());
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
