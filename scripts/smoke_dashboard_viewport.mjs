#!/usr/bin/env node

import { createServer } from 'node:http';
import { mkdtemp, mkdir, readFile, rm, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawn } from 'node:child_process';

const root = process.cwd();
const outputDir = resolve(process.env.DASHBOARD_VIEWPORT_OUTPUT_DIR || 'output/dashboard-viewport-smoke');

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml'
};

function chromeCandidates() {
  return [
    process.env.CHROME_PATH,
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    'google-chrome',
    'chromium',
    'chromium-browser'
  ].filter(Boolean);
}

function resolveChrome() {
  for (const candidate of chromeCandidates()) {
    if (candidate.includes('/') && existsSync(candidate)) return candidate;
    if (!candidate.includes('/')) return candidate;
  }
  throw new Error('Chrome/Chromium not found. Set CHROME_PATH to run dashboard viewport smoke.');
}

function extname(pathname) {
  const match = pathname.match(/(\.[A-Za-z0-9]+)$/);
  return match ? match[1].toLowerCase() : '';
}

async function serveFile(req, res) {
  const url = new URL(req.url || '/', 'http://127.0.0.1');
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === '/') pathname = '/index.html';

  const filePath = resolve(root, `.${pathname}`);
  if (!filePath.startsWith(root)) {
    res.writeHead(403);
    res.end('forbidden');
    return;
  }

  try {
    let body = await readFile(filePath);
    if (pathname === '/index.css') {
      body = Buffer.from(
        body
          .toString('utf8')
          .replace(/@import url\('https:\/\/fonts\.googleapis\.com[^;]+;\n\n/, ''),
        'utf8'
      );
    }
    res.writeHead(200, {
      'content-type': contentTypes[extname(filePath)] || 'application/octet-stream',
      'cache-control': 'no-store'
    });
    res.end(body);
  } catch {
    if (pathname.startsWith('/api/')) {
      res.writeHead(503, { 'content-type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: false, error: 'viewport smoke static server has no API backend' }));
      return;
    }
    res.writeHead(404);
    res.end('not found');
  }
}

function listen(server) {
  return new Promise((resolveListen) => {
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolveListen(`http://127.0.0.1:${address.port}`);
    });
  });
}

function sleep(ms) {
  return new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
}

function runChrome(chromePath, args, timeoutMs = 20_000, successFile) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(chromePath, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
      shell: false
    });
    let settled = false;
    const settle = (fn, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      clearInterval(successPoll);
      fn(value);
    };
    const timeout = setTimeout(() => {
      child.kill('SIGKILL');
      settle(reject, new Error(`Chrome timed out after ${timeoutMs}ms: ${args.join(' ')}`));
    }, timeoutMs);
    const successPoll = successFile
      ? setInterval(async () => {
          try {
            const file = await stat(successFile);
            if (file.size > 0) {
              child.kill('SIGTERM');
              settle(resolveRun, { stdout, stderr });
            }
          } catch {
            // Keep waiting until Chrome writes the expected file or times out.
          }
        }, 250)
      : null;
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => {
      stdout += chunk;
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });
    child.once('error', (error) => settle(reject, error));
    child.once('exit', (code) => {
      if (code === 0) {
        settle(resolveRun, { stdout, stderr });
        return;
      }
      if (successFile && existsSync(successFile)) {
        settle(resolveRun, { stdout, stderr });
        return;
      }
      settle(reject, new Error(`Chrome exited ${code}: ${stderr || stdout}`));
    });
  });
}

async function removeWithRetry(path, {
  attempts = 5,
  delayMs = 250
} = {}) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      await rm(path, { recursive: true, force: true });
      return;
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await sleep(delayMs * attempt);
    }
  }
  throw lastError;
}

async function pngDimensions(path) {
  const file = await readFile(path);
  const signature = file.subarray(0, 8).toString('hex');
  if (signature !== '89504e470d0a1a0a') throw new Error(`${path} is not a PNG`);
  return {
    width: file.readUInt32BE(16),
    height: file.readUInt32BE(20),
    bytes: file.length
  };
}

async function captureViewport({ chromePath, baseUrl, profileDir, name, width, height }) {
  const screenshotPath = join(outputDir, `${name}.png`);
  const commonArgs = [
    '--headless=new',
    '--disable-gpu',
    '--disable-dev-shm-usage',
    '--disable-background-networking',
    '--no-first-run',
    '--no-default-browser-check',
    '--run-all-compositor-stages-before-draw',
    `--user-data-dir=${join(profileDir, name)}`,
    `--window-size=${width},${height}`,
    '--hide-scrollbars',
    '--virtual-time-budget=3000'
  ];

  await runChrome(chromePath, [
    ...commonArgs,
    `--screenshot=${screenshotPath}`,
    `${baseUrl}/index.html`
  ], 30_000, screenshotPath);

  const dimensions = await pngDimensions(screenshotPath);
  if (dimensions.width !== width || dimensions.height !== height) {
    throw new Error(`${name} screenshot size mismatch: ${dimensions.width}x${dimensions.height}`);
  }
  if (dimensions.bytes < 10_000) {
    throw new Error(`${name} screenshot is unexpectedly small (${dimensions.bytes} bytes)`);
  }

  return { name, screenshotPath, ...dimensions };
}

async function main() {
  const chromePath = resolveChrome();
  const profileDir = await mkdtemp(join(tmpdir(), 'run-log-dashboard-smoke-'));
  await mkdir(outputDir, { recursive: true });

  const server = createServer((req, res) => {
    void serveFile(req, res);
  });
  const baseUrl = await listen(server);
  const html = await readFile(resolve(root, 'index.html'), 'utf8');
  for (const expected of [
    'PGHD Review Brief',
    'PGHD 운영 점검',
    '현재 Human State 없음',
    '주간 활동 근거 없음',
    '최근 러닝 기록'
  ]) {
    if (!html.includes(expected)) {
      throw new Error(`Dashboard source is missing "${expected}"`);
    }
  }

  try {
    const results = [];
    results.push(await captureViewport({ chromePath, baseUrl, profileDir, name: 'desktop', width: 1440, height: 1100 }));
    results.push(await captureViewport({ chromePath, baseUrl, profileDir, name: 'mobile', width: 390, height: 1200 }));

    for (const result of results) {
      console.log(`${result.name}: ${result.width}x${result.height}, ${result.bytes} bytes, ${result.screenshotPath}`);
    }
    console.log('Dashboard viewport smoke passed.');
  } finally {
    await new Promise((resolveClose) => server.close(resolveClose));
    await removeWithRetry(profileDir).catch((error) => {
      console.warn(`Warning: failed to remove temporary Chrome profile ${profileDir}: ${error.message}`);
    });
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
