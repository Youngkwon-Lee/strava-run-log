import { supabaseFetch } from '../../lib/supabase-rest.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ACTIVITY_TYPES = new Set([
  'home_exercise',
  'clinic_exercise',
  'gym_training',
  'competition',
  'assessment',
  'daily_walk',
  'telehealth',
  'other'
]);
const ACTIVITY_SOURCES = new Set([
  'manual',
  'apple_health',
  'samsung_health',
  'garmin',
  'imu',
  'camera',
  'app_guided'
]);

function getHeader(req, name) {
  const headers = req.headers || {};
  const target = name.toLowerCase();
  const key = Object.keys(headers).find((headerName) => headerName.toLowerCase() === target);
  return key ? headers[key] : undefined;
}

function isAuthorized(req) {
  const expected = process.env.RUN_LOG_ADMIN_TOKEN || process.env.LIVE_METRICS_TOKEN;
  if (!expected) return false;

  const auth = String(getHeader(req, 'authorization') || '');
  const bearer = auth.startsWith('Bearer ') ? auth.slice('Bearer '.length).trim() : '';
  const headerToken = String(getHeader(req, 'x-run-log-token') || getHeader(req, 'x-live-token') || '').trim();
  return bearer === expected || headerToken === expected;
}

function parseText(body, field, { required = true, maxLength = 160 } = {}) {
  const value = body?.[field] === undefined || body?.[field] === null ? '' : String(body[field]).trim();
  if (!value && required) return { error: `${field} is required` };
  if (value.length > maxLength) return { error: `${field} must be ${maxLength} characters or less` };
  return { value: value || null };
}

function parseUuid(body, field, { required = false } = {}) {
  const value = body?.[field] === undefined || body?.[field] === null ? '' : String(body[field]).trim();
  if (!value && required) return { error: `${field} is required` };
  if (!value) return { value: null };
  if (!UUID_RE.test(value)) return { error: `${field} must be a UUID` };
  return { value };
}

function validatePayload(body) {
  const errors = [];
  const collect = (result) => {
    if (result.error) errors.push(result.error);
    return result.value;
  };

  const source = collect(parseText(body, 'source', { maxLength: 80 }));
  const externalId = collect(parseText(body, 'external_id', { maxLength: 180 }));
  const subjectPersonId = collect(parseUuid(body, 'subject_person_id', { required: true }));
  const organizationId = collect(parseUuid(body, 'organization_id'));
  const orgClientProfileId = collect(parseUuid(body, 'org_client_profile_id'));
  const createdBy = collect(parseUuid(body, 'created_by'));
  const notes = collect(parseText(body, 'notes', { required: false, maxLength: 1000 }));
  const activityType = collect(parseText(body, 'activity_type', { required: false, maxLength: 40 })) || 'other';

  if (activityType && !ACTIVITY_TYPES.has(activityType)) {
    errors.push(`activity_type must be one of: ${Array.from(ACTIVITY_TYPES).join(', ')}`);
  }

  return errors.length
    ? { errors }
    : {
        source,
        externalId,
        subjectPersonId,
        organizationId,
        orgClientProfileId,
        createdBy,
        notes,
        activityType
      };
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function runMetrics(run) {
  const raw = run.raw || {};
  return compactObject({
    distance_meters: run.distance_meters,
    distance_km: raw.distanceKm,
    moving_time_sec: run.moving_time_sec,
    pace_sec_per_km: run.pace_sec_per_km,
    pace: raw.pace,
    average_heartrate: run.average_heartrate,
    average_cadence: run.average_cadence,
    total_elevation_gain_meters: raw.totalElevationGainMeters,
    provider_source: run.source,
    provider_external_id: run.external_id
  });
}

function mapActivitySource(source) {
  const normalized = String(source || '').trim().toLowerCase().replace(/-/g, '_');
  if (ACTIVITY_SOURCES.has(normalized)) return normalized;
  if (normalized === 'strava') return 'app_guided';
  return 'manual';
}

async function findRun(source, externalId) {
  const params = new URLSearchParams({
    select: '*',
    source: `eq.${source}`,
    external_id: `eq.${externalId}`,
    limit: '1'
  });
  const rows = await supabaseFetch(`/run_log_runs?${params.toString()}`);
  return Array.isArray(rows) ? rows[0] : null;
}

async function updateRunLink(source, externalId, patch) {
  const params = new URLSearchParams({
    source: `eq.${source}`,
    external_id: `eq.${externalId}`
  });
  const rows = await supabaseFetch(`/run_log_runs?${params.toString()}`, {
    method: 'PATCH',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify(patch)
  });
  return Array.isArray(rows) ? rows[0] : null;
}

async function createActivitySession(run, payload) {
  const body = compactObject({
    subject_person_id: payload.subjectPersonId,
    organization_id: payload.organizationId,
    activity_type: payload.activityType,
    source: mapActivitySource(run.source),
    status: 'completed',
    performed_at: run.start_date,
    duration_seconds: run.moving_time_sec,
    metrics: runMetrics(run),
    exercise_log: compactObject({
      provider_table: 'run_log_runs',
      provider_source: run.source,
      provider_external_id: run.external_id,
      run: run.raw || {}
    }),
    notes: payload.notes,
    has_timeseries: Boolean(run.raw?.streamSummary?.pointCount),
    timeseries_ref: run.raw?.streamSummary ? { provider: run.source, summary: run.raw.streamSummary } : null,
    created_by: payload.createdBy
  });

  const rows = await supabaseFetch('/activity_sessions', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify(body)
  });
  return Array.isArray(rows) ? rows[0] : null;
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    const parsed = validatePayload(req.body || {});
    if (parsed.errors) return res.status(400).json({ error: 'invalid request', details: parsed.errors });

    const run = await findRun(parsed.source, parsed.externalId);
    if (!run) return res.status(404).json({ error: 'run not found' });

    if (run.activity_session_id) {
      return res.status(200).json({
        ok: true,
        existing: true,
        activitySessionId: run.activity_session_id,
        run: {
          source: run.source,
          externalId: run.external_id
        }
      });
    }

    const session = await createActivitySession(run, parsed);
    if (!session?.id) throw new Error('activity session insert did not return an id');

    const updated = await updateRunLink(parsed.source, parsed.externalId, {
      subject_person_id: parsed.subjectPersonId,
      organization_id: parsed.organizationId,
      org_client_profile_id: parsed.orgClientProfileId,
      activity_session_id: session.id,
      linked_at: new Date().toISOString()
    });

    return res.status(200).json({
      ok: true,
      existing: false,
      activitySessionId: session.id,
      run: {
        source: updated?.source || run.source,
        externalId: updated?.external_id || run.external_id,
        subjectPersonId: updated?.subject_person_id || parsed.subjectPersonId
      }
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
