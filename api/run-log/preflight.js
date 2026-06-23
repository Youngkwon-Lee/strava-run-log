import {
  getPghdConnectionsPersonColumn,
  getPghdConnectionsTable,
  pghdProviderAliases
} from '../../lib/pghd-connections.js';
import { parseBoundedLimit } from '../../lib/http-query.js';
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

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function isMissingTableError(error) {
  return /PGRST205|42P01|relation .+ does not exist|Could not find the table/i.test(
    String(error?.message || error || '')
  );
}

function validateQuery(query) {
  const errors = [];
  const subjectPersonId = String(query.subject_person_id || '').trim();
  const source = String(query.source || '').trim();
  if (!subjectPersonId) errors.push('subject_person_id is required');
  else if (!UUID_RE.test(subjectPersonId)) errors.push('subject_person_id must be a UUID');
  if (source.length > 80) errors.push('source must be 80 characters or less');
  return { errors, subjectPersonId, source: source || null, limit: parseBoundedLimit(query.limit, { defaultValue: 5, max: 20 }) };
}

function check(name, status, message, data = {}, hints = []) {
  return compactObject({
    name,
    status,
    message,
    ...data,
    operatorHints: hints.filter(Boolean)
  });
}

async function checkConnections(subjectPersonId, source) {
  const table = getPghdConnectionsTable();
  const person = getPghdConnectionsPersonColumn();
  assertSimpleIdentifier(table, 'PGHD_CONNECTIONS_TABLE');
  assertSimpleIdentifier(person, 'PGHD_CONNECTIONS_PERSON_COLUMN');

  const params = new URLSearchParams({
    select: `id,${person},provider,provider_user_id,connection_status,last_sync_at,updated_at`,
    [person]: `eq.${subjectPersonId}`,
    order: 'updated_at.desc',
    limit: '20'
  });
  if (source) params.set('provider', `in.(${pghdProviderAliases(source).map(encodeURIComponent).join(',')})`);

  const rows = await supabaseFetch(`/${table}?${params.toString()}`);
  const connectedRows = (rows || []).filter((row) => ['connected', 'active'].includes(String(row.connection_status || '').toLowerCase()));
  if (connectedRows.length) {
    return check('connection_mapping', 'ok', 'PGHD connection mapping exists for this client/source.', {
      count: rows.length,
      latest: connectedRows[0]
    });
  }
  if ((rows || []).length) {
    return check('connection_mapping', 'warning', 'PGHD connection rows exist but none are connected.', {
      count: rows.length,
      latest: rows[0]
    }, ['Review connection_status before trusting ingest freshness.']);
  }
  return check('connection_mapping', 'warning', 'No PGHD connection mapping was found for this client/source.', {
    count: 0
  }, ['Create or repair the provider account mapping in pghd_connections.']);
}

async function checkPhysioPersonContext(subjectPersonId) {
  try {
    const personRows = await supabaseFetch(`/persons?${new URLSearchParams({
      select: 'id',
      id: `eq.${subjectPersonId}`,
      limit: '1'
    }).toString()}`);

    if (!(personRows || []).length) {
      return check('physio_person_context', 'warning', 'No PhysioApp person row was found for this subject_person_id.', {
        count: 0
      }, ['Confirm the PGHD subject_person_id is the PhysioApp persons.id used by the encounter.']);
    }

    try {
      const clientRows = await supabaseFetch(`/org_clients?${new URLSearchParams({
        select: 'id,organization_id,person_id,status',
        person_id: `eq.${subjectPersonId}`,
        limit: '5'
      }).toString()}`);

      if ((clientRows || []).length) {
        return check('physio_person_context', 'ok', 'PhysioApp person and org client context exist for this subject.', {
          count: clientRows.length,
          person: personRows[0],
          latestClient: clientRows[0]
        });
      }

      return check('physio_person_context', 'warning', 'PhysioApp person exists but no org client profile was found.', {
        count: 0,
        person: personRows[0]
      }, ['Register the person as an org client before expecting encounter-room PGHD handoff.']);
    } catch (error) {
      if (!isMissingTableError(error)) throw error;
      return check('physio_person_context', 'warning', 'PhysioApp person exists but org client profile table is unavailable.', {
        count: 0,
        person: personRows[0],
        missingOrgClientsTable: true
      }, ['Confirm the linked DB includes the PhysioApp org_clients table before encounter-room handoff.']);
    }
  } catch (error) {
    if (!isMissingTableError(error)) throw error;
    return check('physio_person_context', 'warning', 'PhysioApp persons table is unavailable in this linked DB.', {
      count: 0,
      missingPersonsTable: true
    }, ['Confirm this run-log deployment is pointed at the PhysioApp-owned Supabase project.']);
  }
}

async function checkActivity(subjectPersonId, source, limit) {
  const table = process.env.RUN_STORE_SUPABASE_TABLE || process.env.RUN_LOG_TABLE || 'run_log_runs';
  assertSimpleIdentifier(table, 'RUN_STORE_SUPABASE_TABLE');
  const params = new URLSearchParams({
    select: 'id,source,external_id,name,start_date,subject_person_id,pghd_connection_id,activity_session_id,linked_at',
    subject_person_id: `eq.${subjectPersonId}`,
    order: 'start_date.desc.nullslast',
    limit: String(limit)
  });
  if (source) params.set('source', `eq.${source}`);

  const rows = await supabaseFetch(`/${table}?${params.toString()}`);
  if ((rows || []).length) {
    return check('activity_ingest', 'ok', 'Provider activity rows exist for this client/source.', {
      count: rows.length,
      latest: rows[0]
    });
  }
  return check('activity_ingest', 'warning', 'No provider activity rows were found for this client/source.', {
    count: 0
  }, ['Confirm provider ingest completed and wrote subject_person_id onto run_log_runs.']);
}

async function checkWeeklySummaries(subjectPersonId, source, limit) {
  const view = process.env.RUN_LOG_WEEKLY_SUMMARY_VIEW || 'run_log_weekly_summaries';
  assertSimpleIdentifier(view, 'RUN_LOG_WEEKLY_SUMMARY_VIEW');
  const params = new URLSearchParams({
    select: 'week_start,subject_person_id,source,run_count,total_km,moving_time_sec,last_run_at',
    subject_person_id: `eq.${subjectPersonId}`,
    order: 'week_start.desc',
    limit: String(limit)
  });
  if (source) params.set('source', `eq.${source}`);

  const rows = await supabaseFetch(`/${view}?${params.toString()}`);
  if ((rows || []).length) {
    return check('weekly_summary', 'ok', 'Weekly PGHD summaries are available for state derivation.', {
      count: rows.length,
      latest: rows[0]
    });
  }
  return check('weekly_summary', 'warning', 'No weekly summaries were found for this client/source.', {
    count: 0
  }, ['Refresh the weekly summary view or confirm run_log_runs has recent rows.']);
}

async function checkStateSnapshots(subjectPersonId, source, limit) {
  const table = process.env.HUMAN_STATE_SNAPSHOTS_TABLE || 'human_state_snapshots';
  assertSimpleIdentifier(table, 'HUMAN_STATE_SNAPSHOTS_TABLE');
  const params = new URLSearchParams({
    select: 'id,subject_person_id,state_type,value,confidence,calculated_at,window_start,window_end,source,provider_source,metadata',
    subject_person_id: `eq.${subjectPersonId}`,
    order: 'calculated_at.desc',
    limit: String(limit)
  });
  if (source) params.set('provider_source', `eq.${source}`);

  try {
    const rows = await supabaseFetch(`/${table}?${params.toString()}`);
    if ((rows || []).length) {
      return check('state_materialization', 'ok', 'Persisted Human State snapshots are available.', {
        count: rows.length,
        latest: rows[0]
      });
    }
    return check('state_materialization', 'warning', 'No persisted Human State snapshots were found.', {
      count: 0
    }, ['Use derive=weekly for preview or POST /api/run-log/state-snapshots to materialize rows.']);
  } catch (error) {
    if (!isMissingTableError(error)) throw error;
    return check('state_materialization', 'warning', 'Human State snapshot tables are not migrated yet.', {
      count: 0,
      missingTable: true
    }, ['Apply the Human State snapshot migration before materializing state rows.']);
  }
}

function buildSummary(checks) {
  const errorCount = checks.filter((item) => item.status === 'error').length;
  const warningCount = checks.filter((item) => item.status === 'warning').length;
  return {
    status: errorCount ? 'error' : warningCount ? 'warning' : 'ok',
    ok: errorCount === 0,
    total: checks.length,
    warningCount,
    errorCount
  };
}

function buildNextActions(checks) {
  const actions = [];
  for (const item of checks) {
    if (item.status === 'ok') continue;
    actions.push(...(item.operatorHints || []));
  }
  return [...new Set(actions)].slice(0, 6);
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    const query = req.query || {};
    const { errors, subjectPersonId, source, limit } = validateQuery(query);
    if (errors.length) return res.status(400).json({ error: 'invalid request', details: errors });

    const checks = [];
    for (const runCheck of [
      () => checkPhysioPersonContext(subjectPersonId),
      () => checkConnections(subjectPersonId, source),
      () => checkActivity(subjectPersonId, source, limit),
      () => checkWeeklySummaries(subjectPersonId, source, limit),
      () => checkStateSnapshots(subjectPersonId, source, limit)
    ]) {
      try {
        checks.push(await runCheck());
      } catch (error) {
        checks.push(check('preflight_query', 'error', error.message, {}, ['Check Supabase env, table names, and service role access.']));
      }
    }

    return res.status(200).json({
      ok: true,
      source: 'run-log-pghd-preflight',
      query: compactObject({
        subjectPersonId,
        source,
        limit
      }),
      summary: buildSummary(checks),
      checks,
      nextActions: buildNextActions(checks)
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
