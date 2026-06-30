import { buildWeeklyActivityStateSnapshots, snapshotRowToApi } from '../../human-state.js';
import { parseBoundedLimit } from '../../http-query.js';
import { buildEmptyResponse } from '../../pghd-empty-response.js';
import { assertSimpleIdentifier, supabaseFetch } from '../../supabase-rest.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const STATE_TYPES = new Set(['fitness', 'fatigue', 'recovery', 'injury_risk', 'adherence', 'training_load']);

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
  return parseBoundedLimit(value, { defaultValue: 30, max: 100 });
}

function addUuidFilter(params, query, field) {
  const value = query[field] === undefined || query[field] === null ? '' : String(query[field]).trim();
  if (!value) return null;
  if (!UUID_RE.test(value)) return `${field} must be a UUID`;
  params.set(field, `eq.${value}`);
  return null;
}

function addStateTypeFilter(params, query) {
  const value = query.state_type === undefined || query.state_type === null ? '' : String(query.state_type).trim();
  if (!value) return null;
  if (!STATE_TYPES.has(value)) return `state_type must be one of ${[...STATE_TYPES].join(', ')}`;
  params.set('state_type', `eq.${value}`);
  return null;
}

function addTextFilter(params, query, field, maxLength = 120) {
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

function snapshotToRow(snapshot) {
  return compactObject({
    subject_person_id: snapshot.subjectPersonId,
    organization_id: snapshot.organizationId,
    org_client_profile_id: snapshot.orgClientProfileId,
    state_type: snapshot.stateType,
    value: snapshot.value,
    confidence: snapshot.confidence,
    calculated_at: snapshot.calculatedAt,
    window_start: snapshot.windowStart,
    window_end: snapshot.windowEnd,
    source: snapshot.source,
    provider_source: snapshot.providerSource,
    metadata: snapshot.metadata
  });
}

function parseBody(req) {
  const body = req.body || {};
  return typeof body === 'object' && body !== null ? body : {};
}

function addBodyUuidErrors(errors, body, field) {
  const value = body[field] === undefined || body[field] === null ? '' : String(body[field]).trim();
  if (!value) return;
  if (!UUID_RE.test(value)) errors.push(`${field} must be a UUID`);
}

function addBodyTextErrors(errors, body, field, maxLength = 120) {
  const value = body[field] === undefined || body[field] === null ? '' : String(body[field]).trim();
  if (!value) return;
  if (value.length > maxLength) errors.push(`${field} must be ${maxLength} characters or less`);
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
  let snapshots = buildWeeklyActivityStateSnapshots(summaries || [], {
    subjectPersonId: query.subject_person_id,
    organizationId: query.organization_id,
    orgClientProfileId: query.org_client_profile_id
  });

  if (query.state_type) snapshots = snapshots.filter((snapshot) => snapshot.stateType === query.state_type);
  return snapshots.slice(0, parseLimit(query.limit));
}

async function deleteExistingSnapshots(table, snapshots) {
  const grouped = new Map();
  for (const snapshot of snapshots) {
    if (!snapshot.subjectPersonId || !snapshot.windowStart || !snapshot.source || !snapshot.stateType) continue;
    const key = [
      snapshot.subjectPersonId,
      snapshot.organizationId || '',
      snapshot.orgClientProfileId || '',
      snapshot.source,
      snapshot.providerSource || '',
      snapshot.windowStart
    ].join('|');
    const group = grouped.get(key) || {
      subjectPersonId: snapshot.subjectPersonId,
      organizationId: snapshot.organizationId,
      orgClientProfileId: snapshot.orgClientProfileId,
      source: snapshot.source,
      providerSource: snapshot.providerSource,
      windowStart: snapshot.windowStart,
      stateTypes: new Set()
    };
    group.stateTypes.add(snapshot.stateType);
    grouped.set(key, group);
  }

  for (const group of grouped.values()) {
    const params = new URLSearchParams({
      subject_person_id: `eq.${group.subjectPersonId}`,
      source: `eq.${group.source}`,
      provider_source: group.providerSource ? `eq.${group.providerSource}` : 'is.null',
      window_start: `eq.${group.windowStart}`,
      state_type: `in.(${[...group.stateTypes].map(encodeURIComponent).join(',')})`
    });
    if (group.organizationId) params.set('organization_id', `eq.${group.organizationId}`);
    else params.set('organization_id', 'is.null');
    if (group.orgClientProfileId) params.set('org_client_profile_id', `eq.${group.orgClientProfileId}`);
    else params.set('org_client_profile_id', 'is.null');

    await supabaseFetch(`/${table}?${params.toString()}`, { method: 'DELETE' });
  }
}

async function insertSnapshotRows(table, snapshots) {
  if (!snapshots.length) return [];
  const rows = snapshots.map(snapshotToRow);
  return supabaseFetch(`/${table}`, {
    method: 'POST',
    headers: {
      Prefer: 'return=representation'
    },
    body: JSON.stringify(rows)
  });
}

function snapshotKey(snapshot) {
  const windowStart = snapshot.windowStart ? String(snapshot.windowStart).slice(0, 10) : '';
  return [
    snapshot.subjectPersonId || '',
    snapshot.organizationId || '',
    snapshot.orgClientProfileId || '',
    snapshot.stateType || '',
    snapshot.providerSource || '',
    windowStart
  ].join('|');
}

async function fetchInputRunRows(snapshot, inputSource) {
  if (!snapshot.subjectPersonId || !snapshot.windowStart) return [];

  const table = process.env.RUN_LOG_TABLE || 'run_log_runs';
  assertSimpleIdentifier(table, 'RUN_LOG_TABLE');

  async function fetchRows(select) {
    const params = new URLSearchParams({
      select,
      subject_person_id: `eq.${snapshot.subjectPersonId}`,
      start_date: `gte.${snapshot.windowStart}`,
      order: 'start_date.asc',
      limit: '100'
    });
    if (snapshot.windowEnd) params.append('start_date', `lte.${snapshot.windowEnd}`);
    if (snapshot.organizationId) params.set('organization_id', `eq.${snapshot.organizationId}`);
    if (snapshot.orgClientProfileId) params.set('org_client_profile_id', `eq.${snapshot.orgClientProfileId}`);
    if (inputSource) params.set('source', `eq.${inputSource}`);
    return supabaseFetch(`/${table}?${params.toString()}`);
  }

  try {
    return (await fetchRows('id,pghd_activity_event_id')) || [];
  } catch (error) {
    if (!isMissingColumnError(error)) throw error;
    return (await fetchRows('id')) || [];
  }
}

async function insertSnapshotInputRows(snapshots, insertedRows, inputSource) {
  if (!snapshots.length || !insertedRows.length) return [];

  const table = process.env.HUMAN_STATE_SNAPSHOT_INPUTS_TABLE || 'human_state_snapshot_inputs';
  assertSimpleIdentifier(table, 'HUMAN_STATE_SNAPSHOT_INPUTS_TABLE');

  const snapshotByKey = new Map(snapshots.map((snapshot) => [snapshotKey(snapshot), snapshot]));
  const runRowsByWindow = new Map();
  const inputRows = [];
  for (const inserted of insertedRows) {
    const original = snapshotByKey.get(snapshotKey(snapshotRowToApi(inserted)));
    if (!original) continue;
    const source = inputSource || original.providerSource || '';
    const runIdsKey = [
      original.subjectPersonId || '',
      original.organizationId || '',
      original.orgClientProfileId || '',
      original.windowStart || '',
      original.windowEnd || '',
      source
    ].join('|');
    if (!runRowsByWindow.has(runIdsKey)) {
      runRowsByWindow.set(runIdsKey, await fetchInputRunRows(original, source));
    }
    const runRows = runRowsByWindow.get(runIdsKey) || [];
    for (const runRow of runRows) {
      if (!runRow.id) continue;
      inputRows.push(compactObject({
        snapshot_id: inserted.id,
        run_log_run_id: runRow.id,
        pghd_activity_event_id: runRow.pghd_activity_event_id,
        weight: 1
      }));
    }
  }

  if (!inputRows.length) return [];
  return supabaseFetch(`/${table}`, {
    method: 'POST',
    headers: {
      Prefer: 'return=representation'
    },
    body: JSON.stringify(inputRows)
  });
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

async function enrichInputRowsWithActivities(inputRows) {
  const activityByRunId = await fetchRunActivitySummaries((inputRows || []).map((row) => row.run_log_run_id));
  return (inputRows || []).map((row) => ({
    ...row,
    activity: activityByRunId.get(row.run_log_run_id)
  }));
}

function inputRowToApiInput(input) {
  return compactObject({
    runLogRunId: input.run_log_run_id,
    pghdActivityEventId: input.pghd_activity_event_id,
    weight: input.weight,
    activity: input.activity
  });
}

async function enrichDerivedSnapshotsWithInputs(snapshots, includeInputs = true) {
  if (!includeInputs || !snapshots?.length) return snapshots;

  try {
    const runRowsByWindow = new Map();
    const inputRows = [];
    for (const snapshot of snapshots) {
      const source = snapshot.providerSource || '';
      const runIdsKey = [
        snapshot.subjectPersonId || '',
        snapshot.organizationId || '',
        snapshot.orgClientProfileId || '',
        snapshot.windowStart || '',
        snapshot.windowEnd || '',
        source
      ].join('|');
      if (!runRowsByWindow.has(runIdsKey)) {
        runRowsByWindow.set(runIdsKey, await fetchInputRunRows(snapshot, source));
      }
      for (const runRow of runRowsByWindow.get(runIdsKey) || []) {
        if (!runRow.id) continue;
        inputRows.push(compactObject({
          snapshot_key: snapshotKey(snapshot),
          run_log_run_id: runRow.id,
          pghd_activity_event_id: runRow.pghd_activity_event_id,
          weight: 1
        }));
      }
    }

    const enrichedInputs = await enrichInputRowsWithActivities(inputRows);
    const inputsBySnapshotKey = new Map();
    for (const input of enrichedInputs) {
      const list = inputsBySnapshotKey.get(input.snapshot_key) || [];
      list.push(inputRowToApiInput(input));
      inputsBySnapshotKey.set(input.snapshot_key, list);
    }

    return snapshots.map((snapshot) =>
      compactObject({
        ...snapshot,
        inputs: inputsBySnapshotKey.get(snapshotKey(snapshot))
      })
    );
  } catch {
    return snapshots;
  }
}

function stateQueryResponse(query) {
  return compactObject({
    subjectPersonId: query.subject_person_id,
    orgClientProfileId: query.org_client_profile_id,
    organizationId: query.organization_id,
    stateType: query.state_type,
    sourceFilter: query.source,
    limit: parseLimit(query.limit)
  });
}

function derivedStateResponse(query, snapshots, extra = {}) {
  return {
    ok: true,
    source: 'human-state-snapshots-derived',
    derived: true,
    query: stateQueryResponse(query),
    snapshots,
    count: snapshots.length,
    ...extra,
    ...(snapshots.length ? {} : buildEmptyResponse('no_derived_state_snapshots', query))
  };
}

export default async function handler(req, res) {
  try {
    if (!['GET', 'POST'].includes(req.method)) return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    const table = process.env.HUMAN_STATE_SNAPSHOTS_TABLE || 'human_state_snapshots';
    assertSimpleIdentifier(table, 'HUMAN_STATE_SNAPSHOTS_TABLE');

    if (req.method === 'POST') {
      const body = parseBody(req);
      const errors = [];
      addBodyUuidErrors(errors, body, 'subject_person_id');
      addBodyUuidErrors(errors, body, 'organization_id');
      addBodyUuidErrors(errors, body, 'org_client_profile_id');
      addBodyTextErrors(errors, body, 'source', 80);
      if (!body.subject_person_id && !body.org_client_profile_id) {
        errors.push('subject_person_id or org_client_profile_id is required');
      }
      if (body.derive && body.derive !== 'weekly') {
        errors.push('derive must be weekly');
      }
      if (body.state_type && !STATE_TYPES.has(String(body.state_type))) {
        errors.push(`state_type must be one of ${[...STATE_TYPES].join(', ')}`);
      }
      if (errors.length) return res.status(400).json({ error: 'invalid request', details: errors });

      const snapshots = await fetchDerivedWeeklySnapshots({
        subject_person_id: body.subject_person_id,
        organization_id: body.organization_id,
        org_client_profile_id: body.org_client_profile_id,
        state_type: body.state_type,
        source: body.source,
        after: body.after,
        before: body.before,
        limit: body.limit || 12
      });

      try {
        await deleteExistingSnapshots(table, snapshots);
        const inserted = await insertSnapshotRows(table, snapshots);
        const insertedInputs = await insertSnapshotInputRows(snapshots, inserted || [], body.source);
        const enrichedInputs = await enrichInputRowsWithActivities(insertedInputs || []);
        const inputsBySnapshotId = new Map();
        for (const input of enrichedInputs) {
          const list = inputsBySnapshotId.get(input.snapshot_id) || [];
          list.push(input);
          inputsBySnapshotId.set(input.snapshot_id, list);
        }
        const persisted = (inserted || []).map((row) => snapshotRowToApi(row));

        return res.status(200).json({
          ok: true,
          source: 'human-state-snapshots',
          persisted: true,
          replaced: true,
          snapshots: (inserted || []).map((row) => snapshotRowToApi(row, inputsBySnapshotId.get(row.id) || [])),
          count: persisted.length
        });
      } catch (error) {
        if (!isMissingStateTableError(error)) throw error;
        return res.status(409).json({
          error: 'state snapshot tables are not migrated',
          details: ['Apply supabase migration 20260622145528_add_activity_event_state_snapshots.sql before materializing snapshots.']
        });
      }
    }

    const query = req.query || {};
    const params = new URLSearchParams({
      select:
        'id,subject_person_id,organization_id,org_client_profile_id,state_type,value,confidence,calculated_at,window_start,window_end,source,provider_source,metadata',
      order: 'calculated_at.desc',
      limit: String(parseLimit(query.limit))
    });

    const errors = [
      addUuidFilter(params, query, 'subject_person_id'),
      addUuidFilter(params, query, 'organization_id'),
      addUuidFilter(params, query, 'org_client_profile_id'),
      addStateTypeFilter(params, query),
      addTextFilter(params, query, 'source', 80)
    ].filter(Boolean);

    if (!query.subject_person_id && !query.org_client_profile_id) {
      errors.push('subject_person_id or org_client_profile_id is required');
    }
    if (query.after) params.set('calculated_at', `gte.${String(query.after).slice(0, 10)}`);
    if (query.before) params.append('calculated_at', `lte.${String(query.before).slice(0, 10)}`);
    if (query.source) {
      params.delete('source');
      params.set('provider_source', `eq.${String(query.source).trim()}`);
    }

    if (errors.length) return res.status(400).json({ error: 'invalid request', details: errors });

    if (String(query.derive || '') === 'weekly') {
      const includeInputs = String(query.include_inputs || 'true') !== 'false';
      const snapshots = await enrichDerivedSnapshotsWithInputs(
        await fetchDerivedWeeklySnapshots(query),
        includeInputs
      );
      return res.status(200).json(derivedStateResponse(query, snapshots));
    }

    let rows;
    let persistedEmptyResponse = null;
    try {
      rows = await supabaseFetch(`/${table}?${params.toString()}`);
    } catch (error) {
      if (!isMissingStateTableError(error)) throw error;
      const includeInputs = String(query.include_inputs || 'true') !== 'false';
      const snapshots = await enrichDerivedSnapshotsWithInputs(
        await fetchDerivedWeeklySnapshots(query),
        includeInputs
      );
      return res.status(200).json(derivedStateResponse(query, snapshots, {
        fallbackReason: 'missing_state_snapshot_tables'
      }));
    }

    if (!(rows || []).length) {
      persistedEmptyResponse = buildEmptyResponse('no_persisted_state_snapshots', query);
    }

    const includeInputs = String(query.include_inputs || 'true') !== 'false';
    const inputsBySnapshotId = includeInputs ? await fetchSnapshotInputs((rows || []).map((row) => row.id)) : new Map();
    const snapshots = (rows || []).map((row) => snapshotRowToApi(row, inputsBySnapshotId.get(row.id) || []));

    return res.status(200).json({
      ok: true,
      source: 'human-state-snapshots',
      query: stateQueryResponse(query),
      snapshots,
      count: snapshots.length,
      ...(persistedEmptyResponse || {})
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
