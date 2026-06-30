import { buildEncounterInsights } from '../../encounter-insights.js';
import { buildWeeklyActivityStateSnapshots, snapshotRowToApi } from '../../human-state.js';
import { parseBoundedLimit } from '../../http-query.js';
import { assertSimpleIdentifier, supabaseFetch } from '../../supabase-rest.js';

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
  return parseBoundedLimit(value, { defaultValue: 12, max: 60 });
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function addUuidFilter(params, query, field) {
  const value = query[field] === undefined || query[field] === null ? '' : String(query[field]).trim();
  if (!value) return null;
  if (!UUID_RE.test(value)) return `${field} must be a UUID`;
  params.set(field, `eq.${value}`);
  return null;
}

function addTextFilter(params, query, field, maxLength = 120) {
  const value = query[field] === undefined || query[field] === null ? '' : String(query[field]).trim();
  if (!value) return null;
  if (value.length > maxLength) return `${field} must be ${maxLength} characters or less`;
  params.set(field, `eq.${value}`);
  return null;
}

function isMissingStateTableError(error) {
  return /PGRST205|42P01|relation .+ does not exist|Could not find .+human_state_snapshot/i.test(
    String(error?.message || error || '')
  );
}

function isMissingColumnError(error) {
  return /PGRST204|42703|Could not find the '.+' column|column .+ does not exist/i.test(
    String(error?.message || error || '')
  );
}

function toRoundedKm(meters) {
  const value = Number(meters);
  return Number.isFinite(value) ? Number((value / 1000).toFixed(2)) : undefined;
}

function runRowToInputActivity(row) {
  const raw = row?.raw && typeof row.raw === 'object' ? row.raw : {};
  return compactObject({
    id: row.id,
    pghdActivityEventId: raw.pghdActivityEventId || row.pghd_activity_event_id,
    source: raw.source || row.source,
    externalId: raw.externalId || row.external_id,
    name: raw.name || row.name,
    startedAt: raw.startedAt || raw.startDate || row.start_date,
    startDateLocal: raw.startDateLocal || row.start_date_local,
    distanceMeters: raw.distanceMeters ?? row.distance_meters,
    distanceKm: raw.distanceKm ?? toRoundedKm(row.distance_meters),
    movingTimeSec: raw.movingTimeSec ?? row.moving_time_sec,
    pace: raw.pace,
    paceSecPerKm: raw.paceSecPerKm ?? row.pace_sec_per_km,
    averageHeartrate: raw.averageHeartrate ?? row.average_heartrate,
    deviceName: raw.deviceName
  });
}

async function fetchDerivedWeeklySnapshots(query) {
  const view = process.env.RUN_LOG_WEEKLY_SUMMARY_VIEW || 'run_log_weekly_summaries';
  assertSimpleIdentifier(view, 'RUN_LOG_WEEKLY_SUMMARY_VIEW');

  const params = new URLSearchParams({
    select:
      'week_start,subject_person_id,organization_id,org_client_profile_id,user_id,source,run_count,total_km,moving_time_sec,moderate_minutes,average_pace_sec_per_km,average_heartrate,average_cadence,first_run_at,last_run_at',
    order: 'week_start.desc',
    limit: String(Math.max(12, parseLimit(query.limit) * 4))
  });

  if (query.subject_person_id) params.set('subject_person_id', `eq.${String(query.subject_person_id).trim()}`);
  if (query.organization_id) params.set('organization_id', `eq.${String(query.organization_id).trim()}`);
  if (query.org_client_profile_id) params.set('org_client_profile_id', `eq.${String(query.org_client_profile_id).trim()}`);
  if (query.source) params.set('source', `eq.${String(query.source).trim()}`);
  if (query.after) params.set('week_start', `gte.${String(query.after).slice(0, 10)}`);
  if (query.before) params.append('week_start', `lte.${String(query.before).slice(0, 10)}`);

  const summaries = await supabaseFetch(`/${view}?${params.toString()}`);
  return buildWeeklyActivityStateSnapshots(summaries || [], {
    subjectPersonId: query.subject_person_id,
    organizationId: query.organization_id,
    orgClientProfileId: query.org_client_profile_id
  });
}

async function fetchPersistedSnapshots(query) {
  const table = process.env.HUMAN_STATE_SNAPSHOTS_TABLE || 'human_state_snapshots';
  assertSimpleIdentifier(table, 'HUMAN_STATE_SNAPSHOTS_TABLE');

  const params = new URLSearchParams({
    select:
      'id,subject_person_id,organization_id,org_client_profile_id,state_type,value,confidence,calculated_at,window_start,window_end,source,provider_source,metadata',
    order: 'calculated_at.desc',
    limit: String(parseLimit(query.limit) * 3)
  });

  addUuidFilter(params, query, 'subject_person_id');
  addUuidFilter(params, query, 'organization_id');
  addUuidFilter(params, query, 'org_client_profile_id');
  addTextFilter(params, query, 'source', 80);
  if (query.after) params.set('calculated_at', `gte.${String(query.after).slice(0, 10)}`);
  if (query.before) params.append('calculated_at', `lte.${String(query.before).slice(0, 10)}`);
  if (query.source) {
    params.delete('source');
    params.set('provider_source', `eq.${String(query.source).trim()}`);
  }

  const rows = await supabaseFetch(`/${table}?${params.toString()}`);
  const inputsBySnapshotId = await fetchSnapshotInputs((rows || []).map((row) => row.id));
  return (rows || []).map((row) => snapshotRowToApi(row, inputsBySnapshotId.get(row.id) || []));
}

async function fetchSnapshotInputs(snapshotIds) {
  const ids = [...new Set(snapshotIds.filter(Boolean))];
  if (!ids.length) return new Map();

  const table = process.env.HUMAN_STATE_SNAPSHOT_INPUTS_TABLE || 'human_state_snapshot_inputs';
  assertSimpleIdentifier(table, 'HUMAN_STATE_SNAPSHOT_INPUTS_TABLE');

  async function fetchRows(select) {
    const params = new URLSearchParams({
      select,
      snapshot_id: `in.(${ids.map(encodeURIComponent).join(',')})`
    });
    return supabaseFetch(`/${table}?${params.toString()}`);
  }

  let rows;
  try {
    rows = await fetchRows('snapshot_id,run_log_run_id,pghd_activity_event_id,weight');
  } catch (error) {
    if (!isMissingColumnError(error)) throw error;
    rows = await fetchRows('snapshot_id,run_log_run_id,weight');
  }

  const activityByRunId = await fetchRunActivitySummaries((rows || []).map((row) => row.run_log_run_id));
  const bySnapshotId = new Map();
  for (const row of rows || []) {
    const list = bySnapshotId.get(row.snapshot_id) || [];
    list.push({
      ...row,
      activity: activityByRunId.get(row.run_log_run_id)
    });
    bySnapshotId.set(row.snapshot_id, list);
  }
  return bySnapshotId;
}

async function fetchRunActivitySummaries(runIds) {
  const ids = [...new Set((runIds || []).filter(Boolean))];
  if (!ids.length) return new Map();

  const table = process.env.RUN_LOG_TABLE || 'run_log_runs';
  assertSimpleIdentifier(table, 'RUN_LOG_TABLE');
  const params = new URLSearchParams({
    id: `in.(${ids.map(encodeURIComponent).join(',')})`,
    limit: String(ids.length)
  });

  async function fetchRows(select) {
    params.set('select', select);
    return supabaseFetch(`/${table}?${params.toString()}`);
  }

  let rows;
  try {
    rows = await fetchRows(
      'id,pghd_activity_event_id,source,external_id,name,start_date,start_date_local,distance_meters,moving_time_sec,pace_sec_per_km,average_heartrate,raw'
    );
  } catch (error) {
    if (!isMissingColumnError(error)) throw error;
    rows = await fetchRows(
      'id,source,external_id,name,start_date,start_date_local,distance_meters,moving_time_sec,pace_sec_per_km,average_heartrate,raw'
    );
  }
  return new Map((rows || []).map((row) => [row.id, runRowToInputActivity(row)]));
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    const query = req.query || {};
    const errors = [
      addUuidFilter(new URLSearchParams(), query, 'subject_person_id'),
      addUuidFilter(new URLSearchParams(), query, 'organization_id'),
      addUuidFilter(new URLSearchParams(), query, 'org_client_profile_id'),
      addTextFilter(new URLSearchParams(), query, 'source', 80)
    ].filter(Boolean);
    if (!query.subject_person_id && !query.org_client_profile_id) {
      errors.push('subject_person_id or org_client_profile_id is required');
    }
    if (String(query.derive || '') && String(query.derive) !== 'weekly') {
      errors.push('derive must be weekly');
    }
    if (errors.length) return res.status(400).json({ error: 'invalid request', details: errors });

    let snapshots = [];
    let derived = String(query.derive || '') === 'weekly';

    if (!derived) {
      try {
        snapshots = await fetchPersistedSnapshots(query);
      } catch (error) {
        if (!isMissingStateTableError(error)) throw error;
        derived = true;
      }
    }

    if (derived || !snapshots.length) {
      snapshots = await fetchDerivedWeeklySnapshots(query);
      derived = true;
    }

    const insights = buildEncounterInsights(snapshots, {
      subjectPersonId: query.subject_person_id,
      organizationId: query.organization_id,
      orgClientProfileId: query.org_client_profile_id
    }).slice(0, parseLimit(query.limit));

    return res.status(200).json({
      ok: true,
      source: derived ? 'encounter-insights-derived' : 'encounter-insights',
      derived,
      query: compactObject({
        subjectPersonId: query.subject_person_id,
        orgClientProfileId: query.org_client_profile_id,
        organizationId: query.organization_id,
        sourceFilter: query.source,
        limit: parseLimit(query.limit)
      }),
      insights,
      count: insights.length
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
