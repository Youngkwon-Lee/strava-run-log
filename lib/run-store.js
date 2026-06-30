import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { attachPghdConnectionToRun } from './pghd-connections.js';
import { assertSimpleIdentifier, supabaseFetch } from './supabase-rest.js';

const DEFAULT_STORE_PATH = process.env.VERCEL
  ? '/tmp/strava-run-log/runs.jsonl'
  : resolve(process.cwd(), '.data/runs.jsonl');

function storePath() {
  return resolve(process.env.RUN_STORE_PATH || DEFAULT_STORE_PATH);
}

function storeBackend() {
  const backend = String(process.env.RUN_STORE_BACKEND || 'file').trim().toLowerCase();
  if (backend === 'file' || backend === 'jsonl') return 'file';
  if (backend === 'supabase') return 'supabase';
  throw new Error(`unsupported RUN_STORE_BACKEND: ${backend}`);
}

function envFlag(value) {
  return /^(1|true|yes|on)$/i.test(String(value || '').trim());
}

function assertFileBackendAllowed() {
  if (!process.env.VERCEL) return;
  if (envFlag(process.env.RUN_STORE_ALLOW_EPHEMERAL_FILE)) return;

  throw new Error(
    'RUN_STORE_BACKEND=file uses ephemeral Vercel /tmp storage. Set RUN_STORE_BACKEND=supabase for durable storage, or set RUN_STORE_ALLOW_EPHEMERAL_FILE=1 only for temporary smoke/dev use.'
  );
}

function nowIso() {
  return new Date().toISOString();
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function maxRawBytes() {
  return Math.max(4096, Number(process.env.RUN_STORE_MAX_RAW_BYTES || 65536));
}

function byteLength(value) {
  return Buffer.byteLength(JSON.stringify(value), 'utf8');
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

  return applyStoragePolicy(compactObject({
    ...input,
    id,
    externalId,
    source,
    provider,
    dataClassification: input.dataClassification || 'PGHD',
    storedAt: input.storedAt || nowIso(),
    updatedAt: input.updatedAt || nowIso()
  }));
}

function applyStoragePolicy(run) {
  const next = { ...run };

  if (next.streams) {
    next.telemetryRef =
      next.telemetryRef ||
      compactObject({
        storage: 'external-required',
        reason: 'streams removed from run_log_runs.raw',
        pointCount: next.streamSummary?.pointCount
      });
    delete next.streams;
  }

  if (Array.isArray(next.routePoints) && next.routePoints.length > 100) {
    next.routePointCount = next.routePointCount || next.routePoints.length;
    next.telemetryRef =
      next.telemetryRef ||
      compactObject({
        storage: 'external-required',
        reason: 'dense route points removed from run_log_runs.raw',
        pointCount: next.routePoints.length
      });
    delete next.routePoints;
  }

  const rawSizeBytes = byteLength({ ...next, rawSizeBytes: undefined });
  if (rawSizeBytes > maxRawBytes()) {
    throw new Error(`run raw payload exceeds RUN_STORE_MAX_RAW_BYTES (${rawSizeBytes} > ${maxRawBytes()})`);
  }

  return compactObject({
    ...next,
    rawSizeBytes
  });
}

async function ensureStoreDir(path) {
  await mkdir(dirname(path), { recursive: true });
}

export async function readStoredRuns(opts = {}) {
  if (storeBackend() === 'supabase') return readSupabaseRuns(opts);
  assertFileBackendAllowed();

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
  assertFileBackendAllowed();

  const path = opts.path || storePath();
  await ensureStoreDir(path);
  const tmpPath = `${path}.${process.pid}.${Date.now()}.tmp`;
  const body = runs.map((run) => JSON.stringify(run)).join('\n');
  await writeFile(tmpPath, body ? `${body}\n` : '', 'utf8');
  await rename(tmpPath, path);
}

export async function upsertStoredRun(run, opts = {}) {
  if (storeBackend() === 'supabase') return upsertSupabaseRun(run, opts);
  assertFileBackendAllowed();

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
  assertSimpleIdentifier(table, 'RUN_STORE_SUPABASE_TABLE');

  return { url, key, table };
}

function isPostgrestMissingColumnError(error) {
  return /PGRST204|42703|Could not find the '.+' column|column .+ does not exist/i.test(
    String(error?.message || error || '')
  );
}

function isPostgrestMissingTableError(error) {
  return /PGRST205|42P01|Could not find the table|relation .+ does not exist/i.test(
    String(error?.message || error || '')
  );
}

function toPghdActivityEventRow(run) {
  const normalized = normalizeStoredRun(run);
  return compactObject({
    source: normalized.source,
    external_id: normalized.externalId,
    source_record_type: normalized.sourceRecordType || 'activity_event',
    activity_type: normalized.activityType || 'running',
    subject_person_id: normalized.subjectPersonId,
    organization_id: normalized.organizationId,
    org_client_profile_id: normalized.orgClientProfileId,
    pghd_connection_id: normalized.pghdConnectionId,
    user_id: normalized.userId,
    name: normalized.name,
    started_at: normalized.startDate || normalized.startedAt,
    ended_at: normalized.endedAt,
    duration_seconds: normalized.movingTimeSec || normalized.elapsedTimeSec,
    metrics: compactObject({
      distance_meters: normalized.distanceMeters,
      moving_time_sec: normalized.movingTimeSec,
      elapsed_time_sec: normalized.elapsedTimeSec,
      pace_sec_per_km: normalized.paceSecPerKm,
      average_heartrate: normalized.averageHeartrate,
      max_heartrate: normalized.maxHeartrate,
      average_cadence: normalized.averageCadence,
      calories: normalized.calories,
      total_elevation_gain_meters: normalized.totalElevationGainMeters,
      device_name: normalized.deviceName
    }),
    raw: normalized,
    data_classification: normalized.dataClassification,
    imported_at: normalized.importedAt,
    updated_at: normalized.updatedAt
  });
}

async function upsertPghdActivityEvent(run) {
  const table = process.env.PGHD_ACTIVITY_EVENTS_TABLE || 'pghd_activity_events';
  assertSimpleIdentifier(table, 'PGHD_ACTIVITY_EVENTS_TABLE');
  const params = new URLSearchParams({ on_conflict: 'source,external_id' });
  const rows = await supabaseFetch(`/${table}?${params.toString()}`, {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify(toPghdActivityEventRow(run))
  });
  return rows?.[0] || null;
}

function toSupabaseRow(run, opts = {}) {
  const normalized = normalizeStoredRun(run);
  const row = compactObject({
    source: normalized.source,
    external_id: normalized.externalId,
    user_id: normalized.userId,
    name: normalized.name,
    start_date: normalized.startDate || normalized.startedAt,
    start_date_local: normalized.startDateLocal,
    activity_type: normalized.activityType || 'running',
    ended_at: normalized.endedAt,
    distance_meters: normalized.distanceMeters,
    moving_time_sec: normalized.movingTimeSec,
    pace_sec_per_km: normalized.paceSecPerKm,
    average_heartrate: normalized.averageHeartrate,
    max_heartrate: normalized.maxHeartrate,
    average_cadence: normalized.averageCadence,
    calories: normalized.calories,
    source_record_type: normalized.sourceRecordType || 'activity_event',
    imported_at: normalized.importedAt,
    subject_person_id: normalized.subjectPersonId,
    organization_id: normalized.organizationId,
    org_client_profile_id: normalized.orgClientProfileId,
    activity_session_id: normalized.activitySessionId,
    pghd_activity_event_id: normalized.pghdActivityEventId,
    pghd_connection_id: normalized.pghdConnectionId,
    linked_at: normalized.linkedAt,
    data_classification: normalized.dataClassification,
    raw_size_bytes: normalized.rawSizeBytes,
    telemetry_ref: normalized.telemetryRef,
    raw: normalized,
    updated_at: normalized.updatedAt
  });

  if (opts.legacyRunLogColumns) {
    delete row.activity_type;
    delete row.ended_at;
    delete row.max_heartrate;
    delete row.calories;
    delete row.source_record_type;
    delete row.imported_at;
    delete row.pghd_activity_event_id;
  }

  return row;
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
    activityType: raw.activityType || row.activity_type,
    endedAt: raw.endedAt || row.ended_at,
    distanceMeters: raw.distanceMeters ?? row.distance_meters,
    movingTimeSec: raw.movingTimeSec ?? row.moving_time_sec,
    paceSecPerKm: raw.paceSecPerKm ?? row.pace_sec_per_km,
    averageHeartrate: raw.averageHeartrate ?? row.average_heartrate,
    maxHeartrate: raw.maxHeartrate ?? row.max_heartrate,
    averageCadence: raw.averageCadence ?? row.average_cadence,
    calories: raw.calories ?? row.calories,
    sourceRecordType: raw.sourceRecordType || row.source_record_type,
    importedAt: raw.importedAt || row.imported_at,
    subjectPersonId: raw.subjectPersonId || row.subject_person_id,
    organizationId: raw.organizationId || row.organization_id,
    orgClientProfileId: raw.orgClientProfileId || row.org_client_profile_id,
    activitySessionId: raw.activitySessionId || row.activity_session_id,
    pghdActivityEventId: raw.pghdActivityEventId || row.pghd_activity_event_id,
    pghdConnectionId: raw.pghdConnectionId || row.pghd_connection_id,
    linkedAt: raw.linkedAt || row.linked_at,
    dataClassification: raw.dataClassification || row.data_classification,
    rawSizeBytes: raw.rawSizeBytes || row.raw_size_bytes,
    telemetryRef: raw.telemetryRef || row.telemetry_ref,
    storedAt: raw.storedAt || row.created_at,
    updatedAt: raw.updatedAt || row.updated_at
  });
}

async function readSupabaseRuns(opts = {}) {
  const { table } = getSupabaseConfig();
  const limit = Math.min(5000, Math.max(1, Number(opts.limit || process.env.RUN_STORE_READ_LIMIT || 1000)));

  async function fetchRows(select) {
    const params = new URLSearchParams({
      select,
      order: 'start_date.desc.nullslast',
      limit: String(limit)
    });
    return supabaseFetch(`/${table}?${params.toString()}`);
  }

  let rows;
  try {
    rows = await fetchRows(
      'source,external_id,user_id,name,start_date,start_date_local,activity_type,ended_at,distance_meters,moving_time_sec,pace_sec_per_km,average_heartrate,max_heartrate,average_cadence,calories,source_record_type,imported_at,subject_person_id,organization_id,org_client_profile_id,activity_session_id,pghd_activity_event_id,pghd_connection_id,linked_at,data_classification,raw_size_bytes,telemetry_ref,created_at,updated_at,raw'
    );
  } catch (error) {
    if (!isPostgrestMissingColumnError(error)) throw error;
    rows = await fetchRows(
      'source,external_id,user_id,name,start_date,start_date_local,distance_meters,moving_time_sec,pace_sec_per_km,average_heartrate,average_cadence,subject_person_id,organization_id,org_client_profile_id,activity_session_id,pghd_connection_id,linked_at,data_classification,raw_size_bytes,telemetry_ref,created_at,updated_at,raw'
    );
  }

  return sortStoredRunsNewestFirst((rows || []).map(fromSupabaseRow));
}

async function upsertSupabaseRun(run, opts = {}) {
  const { table } = getSupabaseConfig();
  let connection = null;
  let runForUpsert = run;
  if (opts.resolveConnection !== false) {
    const attached = await attachPghdConnectionToRun(run);
    runForUpsert = attached.run;
    connection = attached.connection;
  }

  const nextRun = normalizeStoredRun({
    ...runForUpsert,
    connectionResolution: connection
  });
  let pghdActivityEvent = null;
  try {
    pghdActivityEvent = await upsertPghdActivityEvent(nextRun);
  } catch (error) {
    if (!isPostgrestMissingTableError(error) && !isPostgrestMissingColumnError(error)) throw error;
  }
  const runWithActivityEvent = normalizeStoredRun({
    ...nextRun,
    pghdActivityEventId: pghdActivityEvent?.id || nextRun.pghdActivityEventId
  });
  const params = new URLSearchParams({ on_conflict: 'source,external_id' });
  const postOptions = (row) => ({
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify(row)
  });

  let rows;
  try {
    rows = await supabaseFetch(`/${table}?${params.toString()}`, postOptions(toSupabaseRow(runWithActivityEvent)));
  } catch (error) {
    if (!isPostgrestMissingColumnError(error)) throw error;
    rows = await supabaseFetch(
      `/${table}?${params.toString()}`,
      postOptions(toSupabaseRow(runWithActivityEvent, { legacyRunLogColumns: true }))
    );
  }

  const storedRun = Array.isArray(rows) && rows[0] ? fromSupabaseRow(rows[0]) : runWithActivityEvent;
  const count = opts.skipCount ? undefined : (await readSupabaseRuns()).length;

  return compactObject({
    run: storedRun,
    pghdActivityEvent,
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
