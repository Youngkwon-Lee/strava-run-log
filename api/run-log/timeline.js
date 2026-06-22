import { assertSimpleIdentifier, supabaseFetch } from '../../lib/supabase-rest.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

function parseLimit(value) {
  return Math.min(100, Math.max(1, Number(value || 30)));
}

function addUuidFilter(params, query, field) {
  const value = query[field] === undefined || query[field] === null ? '' : String(query[field]).trim();
  if (!value) return null;
  if (!UUID_RE.test(value)) return `${field} must be a UUID`;
  params.set(field, `eq.${value}`);
  return null;
}

function addTextFilter(params, query, field, maxLength = 160) {
  const value = query[field] === undefined || query[field] === null ? '' : String(query[field]).trim();
  if (!value) return null;
  if (value.length > maxLength) return `${field} must be ${maxLength} characters or less`;
  params.set(field, `eq.${value}`);
  return null;
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function formatPace(secondsPerKm) {
  const value = Number(secondsPerKm);
  if (!Number.isFinite(value) || value <= 0) return null;
  const minutes = Math.floor(value / 60);
  const seconds = Math.round(value % 60);
  return `${minutes}:${String(seconds).padStart(2, '0')}/km`;
}

function runToTimelineItem(run, sessionById) {
  const raw = run.raw && typeof run.raw === 'object' ? run.raw : {};
  const session = run.activity_session_id ? sessionById.get(run.activity_session_id) : null;
  const distanceMeters = Number(run.distance_meters || raw.distanceMeters || 0);
  const movingTimeSec = Number(run.moving_time_sec || raw.movingTimeSec || 0);
  const paceSecPerKm = Number(run.pace_sec_per_km || raw.paceSecPerKm || 0);

  return compactObject({
    id: `${run.source}:${run.external_id}`,
    kind: 'run',
    source: run.source,
    externalId: run.external_id,
    name: run.name || raw.name || `${run.source || 'provider'} run`,
    startedAt: run.start_date || raw.startDate || raw.startedAt,
    subjectPersonId: run.subject_person_id,
    userId: run.user_id,
    providerUserId: raw.providerUserId || raw.userId || run.user_id,
    pghdConnectionId: run.pghd_connection_id,
    activitySessionId: run.activity_session_id,
    linkedAt: run.linked_at,
    promoted: Boolean(run.activity_session_id),
    dataClassification: run.data_classification,
    metrics: compactObject({
      distanceMeters,
      distanceKm: distanceMeters ? Number((distanceMeters / 1000).toFixed(2)) : undefined,
      movingTimeSec,
      paceSecPerKm: Number.isFinite(paceSecPerKm) && paceSecPerKm > 0 ? Math.round(paceSecPerKm) : undefined,
      pace: raw.pace || formatPace(paceSecPerKm),
      averageHeartrate: run.average_heartrate ?? raw.averageHeartrate,
      averageCadence: run.average_cadence ?? raw.averageCadence
    }),
    session: session
      ? compactObject({
          id: session.id,
          activityType: session.activity_type,
          source: session.source,
          status: session.status,
          performedAt: session.performed_at,
          durationSeconds: session.duration_seconds,
          hasTimeseries: session.has_timeseries,
          notes: session.notes
        })
      : undefined
  });
}

async function fetchActivitySessions(sessionIds) {
  const ids = [...new Set(sessionIds.filter(Boolean))];
  if (!ids.length) return new Map();

  const params = new URLSearchParams({
    select: 'id,activity_type,source,status,performed_at,duration_seconds,has_timeseries,notes',
    id: `in.(${ids.map(encodeURIComponent).join(',')})`
  });
  const rows = await supabaseFetch(`/activity_sessions?${params.toString()}`);
  return new Map((rows || []).map((row) => [row.id, row]));
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    const table = process.env.RUN_STORE_SUPABASE_TABLE || 'run_log_runs';
    assertSimpleIdentifier(table, 'RUN_STORE_SUPABASE_TABLE');

    const query = req.query || {};
    const params = new URLSearchParams({
      select: 'source,external_id,user_id,name,start_date,distance_meters,moving_time_sec,pace_sec_per_km,average_heartrate,average_cadence,subject_person_id,pghd_connection_id,activity_session_id,linked_at,data_classification,raw',
      order: 'start_date.desc.nullslast',
      limit: String(parseLimit(query.limit))
    });

    const errors = [
      addUuidFilter(params, query, 'subject_person_id'),
      addUuidFilter(params, query, 'pghd_connection_id'),
      addTextFilter(params, query, 'user_id', 120),
      addTextFilter(params, query, 'source', 80)
    ].filter(Boolean);

    if (query.after) params.set('start_date', `gte.${String(query.after).slice(0, 10)}`);
    if (query.before) params.append('start_date', `lte.${String(query.before).slice(0, 10)}`);

    if (!query.subject_person_id && !query.user_id && !query.pghd_connection_id) {
      errors.push('subject_person_id, user_id, or pghd_connection_id is required');
    }
    if (errors.length) return res.status(400).json({ error: 'invalid request', details: errors });

    const runs = await supabaseFetch(`/${table}?${params.toString()}`);
    const sessionById = await fetchActivitySessions((runs || []).map((run) => run.activity_session_id));
    const items = (runs || []).map((run) => runToTimelineItem(run, sessionById));

    return res.status(200).json({
      ok: true,
      source: 'run-log-timeline',
      query: compactObject({
        subjectPersonId: query.subject_person_id,
        userId: query.user_id,
        pghdConnectionId: query.pghd_connection_id,
        source: query.source,
        limit: parseLimit(query.limit)
      }),
      timeline: items,
      count: items.length
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
