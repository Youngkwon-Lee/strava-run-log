import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const DEFAULT_STORE_PATH = process.env.VERCEL
  ? '/tmp/strava-run-log/runs.jsonl'
  : resolve(process.cwd(), '.data/runs.jsonl');

function storePath() {
  return resolve(process.env.RUN_STORE_PATH || DEFAULT_STORE_PATH);
}

function storeBackend() {
  return String(process.env.RUN_STORE_BACKEND || 'file').trim().toLowerCase();
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
    updatedAt: input.updatedAt || nowIso()
  });
}

async function ensureStoreDir(path) {
  await mkdir(dirname(path), { recursive: true });
}

export async function readStoredRuns(opts = {}) {
  if (storeBackend() === 'supabase') return readSupabaseRuns(opts);

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
  if (storeBackend() === 'supabase') {
    throw new Error('writeStoredRuns is not supported for RUN_STORE_BACKEND=supabase; use upsertStoredRun');
  }

  const path = opts.path || storePath();
  await ensureStoreDir(path);
  const tmpPath = `${path}.${process.pid}.${Date.now()}.tmp`;
  const body = runs.map((run) => JSON.stringify(run)).join('\n');
  await writeFile(tmpPath, body ? `${body}\n` : '', 'utf8');
  await rename(tmpPath, path);
}

export async function upsertStoredRun(run, opts = {}) {
  if (storeBackend() === 'supabase') return upsertSupabaseRun(run, opts);

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

function getSupabaseConfig() {
  const url = String(process.env.SUPABASE_URL || '').replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SECRET_KEY;
  const table = process.env.RUN_STORE_SUPABASE_TABLE || 'run_log_runs';

  if (!url || !key) {
    throw new Error('missing Supabase env: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  }
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(table)) {
    throw new Error('RUN_STORE_SUPABASE_TABLE must be a simple table identifier');
  }

  return { url, key, table };
}

function supabaseHeaders(key, extra = {}) {
  return {
    apikey: key,
    authorization: `Bearer ${key}`,
    'content-type': 'application/json',
    ...extra
  };
}

function toSupabaseRow(run) {
  const normalized = normalizeStoredRun(run);
  return compactObject({
    source: normalized.source,
    external_id: normalized.externalId,
    user_id: normalized.userId,
    name: normalized.name,
    start_date: normalized.startDate || normalized.startedAt,
    start_date_local: normalized.startDateLocal,
    distance_meters: normalized.distanceMeters,
    moving_time_sec: normalized.movingTimeSec,
    pace_sec_per_km: normalized.paceSecPerKm,
    average_heartrate: normalized.averageHeartrate,
    average_cadence: normalized.averageCadence,
    raw: normalized,
    updated_at: normalized.updatedAt
  });
}

function fromSupabaseRow(row) {
  const raw = row?.raw && typeof row.raw === 'object' ? row.raw : {};
  return normalizeStoredRun({
    ...raw,
    source: raw.source || row.source,
    externalId: raw.externalId || row.external_id,
    userId: raw.userId || row.user_id,
    name: raw.name || row.name,
    startDate: raw.startDate || row.start_date,
    startDateLocal: raw.startDateLocal || row.start_date_local,
    distanceMeters: raw.distanceMeters ?? row.distance_meters,
    movingTimeSec: raw.movingTimeSec ?? row.moving_time_sec,
    paceSecPerKm: raw.paceSecPerKm ?? row.pace_sec_per_km,
    averageHeartrate: raw.averageHeartrate ?? row.average_heartrate,
    averageCadence: raw.averageCadence ?? row.average_cadence,
    storedAt: raw.storedAt || row.created_at,
    updatedAt: raw.updatedAt || row.updated_at
  });
}

async function supabaseFetch(path, init = {}) {
  const { url, key } = getSupabaseConfig();
  const response = await fetch(`${url}/rest/v1${path}`, {
    ...init,
    headers: supabaseHeaders(key, init.headers)
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`Supabase run store request failed: ${response.status}${text ? ` ${text.slice(0, 180)}` : ''}`);
  }

  if (response.status === 204) return null;
  return response.json();
}

async function readSupabaseRuns(opts = {}) {
  const { table } = getSupabaseConfig();
  const limit = Math.min(5000, Math.max(1, Number(opts.limit || process.env.RUN_STORE_READ_LIMIT || 1000)));
  const params = new URLSearchParams({
    select: 'source,external_id,user_id,name,start_date,start_date_local,distance_meters,moving_time_sec,pace_sec_per_km,average_heartrate,average_cadence,created_at,updated_at,raw',
    order: 'start_date.desc.nullslast',
    limit: String(limit)
  });
  const rows = await supabaseFetch(`/${table}?${params.toString()}`);
  return sortStoredRunsNewestFirst((rows || []).map(fromSupabaseRow));
}

async function upsertSupabaseRun(run, opts = {}) {
  const { table } = getSupabaseConfig();
  const nextRun = normalizeStoredRun(run);
  const params = new URLSearchParams({ on_conflict: 'source,external_id' });
  const rows = await supabaseFetch(`/${table}?${params.toString()}`, {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify(toSupabaseRow(nextRun))
  });

  const storedRun = Array.isArray(rows) && rows[0] ? fromSupabaseRow(rows[0]) : nextRun;
  const count = opts.skipCount ? undefined : (await readSupabaseRuns()).length;

  return compactObject({
    run: storedRun,
    inserted: undefined,
    count
  });
}

function formatPace(secondsPerKm) {
  if (!Number.isFinite(secondsPerKm) || secondsPerKm <= 0) return undefined;
  const minutes = Math.floor(secondsPerKm / 60);
  const seconds = Math.round(secondsPerKm % 60);
  return `${minutes}:${String(seconds).padStart(2, '0')}/km`;
}
