import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const DEFAULT_STORE_PATH = process.env.VERCEL
  ? '/tmp/strava-run-log/runs.jsonl'
  : resolve(process.cwd(), '.data/runs.jsonl');

function storePath() {
  return resolve(process.env.RUN_STORE_PATH || DEFAULT_STORE_PATH);
}

function nowIso() {
  return new Date().toISOString();
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function getStartTime(run) {
  const value = run?.startDate || run?.startedAt || run?.startDateLocal;
  const time = value ? Date.parse(value) : 0;
  return Number.isFinite(time) ? time : 0;
}

function getExternalId(run) {
  return String(run?.externalId || run?.id || run?.externalRunId || '');
}

function getStoreKey(run) {
  const provider = String(run?.provider || run?.source || 'unknown');
  const externalId = getExternalId(run);
  return `${provider}:${externalId || getStartTime(run)}`;
}

function normalizeStoredRun(input) {
  const source = input.source || input.provider || 'unknown';
  const provider = source;
  const externalId = String(input.externalId || input.externalRunId || input.id || '');
  const id = input.id || externalId || getStoreKey({ provider, ...input });

  return compactObject({
    ...input,
    id,
    externalId,
    source,
    provider,
    storedAt: input.storedAt || nowIso(),
    updatedAt: nowIso()
  });
}

async function ensureStoreDir(path) {
  await mkdir(dirname(path), { recursive: true });
}

export async function readStoredRuns(opts = {}) {
  const path = opts.path || storePath();
  try {
    const text = await readFile(path, 'utf8');
    return text
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  } catch (e) {
    if (e.code === 'ENOENT') return [];
    throw e;
  }
}

export async function writeStoredRuns(runs, opts = {}) {
  const path = opts.path || storePath();
  await ensureStoreDir(path);
  const tmpPath = `${path}.${process.pid}.${Date.now()}.tmp`;
  const body = runs.map((run) => JSON.stringify(run)).join('\n');
  await writeFile(tmpPath, body ? `${body}\n` : '', 'utf8');
  await rename(tmpPath, path);
}

export async function upsertStoredRun(run, opts = {}) {
  const path = opts.path || storePath();
  const nextRun = normalizeStoredRun(run);
  const key = getStoreKey(nextRun);
  const runs = await readStoredRuns({ path });
  const index = runs.findIndex((item) => getStoreKey(item) === key);

  if (index >= 0) {
    nextRun.storedAt = runs[index].storedAt || nextRun.storedAt;
    runs[index] = { ...runs[index], ...nextRun };
  } else {
    runs.push(nextRun);
  }

  const sorted = sortStoredRunsNewestFirst(runs);
  await writeStoredRuns(sorted, { path });
  return {
    run: nextRun,
    inserted: index === -1,
    count: sorted.length
  };
}

export function sortStoredRunsNewestFirst(runs) {
  return [...runs].sort((a, b) => getStartTime(b) - getStartTime(a));
}

export function filterStoredRuns(runs, opts = {}) {
  const source = opts.source ? String(opts.source) : '';
  const minDistanceMeters = Math.max(0, Number(opts.minDistanceKm || 0) * 1000);
  const after = opts.after ? Date.parse(opts.after) : Number.NaN;
  const before = opts.before ? Date.parse(opts.before) : Number.NaN;

  return sortStoredRunsNewestFirst(runs).filter((run) => {
    if (source && run.source !== source && run.provider !== source) return false;
    if (minDistanceMeters && Number(run.distanceMeters || 0) < minDistanceMeters) return false;

    const startTime = getStartTime(run);
    if (Number.isFinite(after) && startTime < after) return false;
    if (Number.isFinite(before) && startTime > before) return false;
    return true;
  });
}

export function summarizeStoredRuns(runs) {
  const totalMeters = runs.reduce((sum, run) => sum + Number(run.distanceMeters || 0), 0);
  const movingSec = runs.reduce((sum, run) => sum + Number(run.movingTimeSec || 0), 0);
  const elevationMeters = runs.reduce((sum, run) => sum + Number(run.totalElevationGainMeters || 0), 0);
  const avgPaceSec = totalMeters > 0 ? movingSec / (totalMeters / 1000) : null;
  const hrValues = runs.map((run) => Number(run.averageHeartrate)).filter(Number.isFinite);
  const cadenceValues = runs.map((run) => Number(run.averageCadence)).filter(Number.isFinite);
  const longest = runs.reduce((best, run) => {
    if (!best || Number(run.distanceMeters || 0) > Number(best.distanceMeters || 0)) return run;
    return best;
  }, null);

  return compactObject({
    runCount: runs.length,
    totalKm: Number((totalMeters / 1000).toFixed(2)),
    movingTimeSec: movingSec,
    moderateMinutes: Math.round(movingSec / 60),
    averagePaceSecPerKm: avgPaceSec ? Math.round(avgPaceSec) : undefined,
    averagePace: formatPace(avgPaceSec),
    totalElevationGainMeters: Math.round(elevationMeters),
    averageHeartrate: hrValues.length
      ? Math.round(hrValues.reduce((sum, value) => sum + value, 0) / hrValues.length)
      : undefined,
    averageCadence: cadenceValues.length
      ? Math.round(cadenceValues.reduce((sum, value) => sum + value, 0) / cadenceValues.length)
      : undefined,
    longestRun: longest
      ? compactObject({
          id: longest.id,
          name: longest.name,
          source: longest.source,
          distanceKm: longest.distanceKm,
          movingTime: longest.movingTime,
          pace: longest.pace,
          startDate: longest.startDate || longest.startedAt,
          startDateLocal: longest.startDateLocal
        })
      : undefined
  });
}

export function normalizeAppleHealthRunForStore(parsed, summary, coaching) {
  return compactObject({
    id: parsed.externalRunId,
    externalId: parsed.externalRunId,
    source: 'apple-health',
    provider: 'apple-health',
    userId: parsed.userId,
    name: `${parsed.sourceApp || 'Apple Health'} Run`,
    startDate: parsed.startedAt,
    startedAt: parsed.startedAt,
    endedAt: parsed.endedAt,
    distanceMeters: parsed.distanceM,
    distanceKm: summary.distanceKm,
    movingTimeSec: parsed.movingTimeS,
    movingTime: summary.movingTime,
    elapsedTimeSec: parsed.elapsedTimeS,
    elapsedTime: summary.elapsedTime,
    paceSecPerKm: summary.paceSecPerKm,
    pace: summary.pace,
    totalElevationGainMeters: parsed.elevationGainM,
    averageHeartrate: parsed.avgHr,
    maxHeartrate: parsed.maxHr,
    averageCadence: parsed.cadenceAvg,
    calories: parsed.calories,
    deviceName: parsed.deviceSource,
    sourceApp: parsed.sourceApp,
    splits: parsed.splits,
    routePointCount: parsed.routePoints.length,
    coaching
  });
}

function formatPace(secondsPerKm) {
  if (!Number.isFinite(secondsPerKm) || secondsPerKm <= 0) return undefined;
  const minutes = Math.floor(secondsPerKm / 60);
  const seconds = Math.round(secondsPerKm % 60);
  return `${minutes}:${String(seconds).padStart(2, '0')}/km`;
}
