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
  return Math.min(260, Math.max(1, Number(value || 52)));
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

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    const view = process.env.RUN_LOG_WEEKLY_SUMMARY_VIEW || 'run_log_weekly_summaries';
    assertSimpleIdentifier(view, 'RUN_LOG_WEEKLY_SUMMARY_VIEW');

    const params = new URLSearchParams({
      select:
        'week_start,subject_person_id,organization_id,org_client_profile_id,user_id,source,run_count,total_km,moving_time_sec,moderate_minutes,average_pace_sec_per_km,average_heartrate,average_cadence,first_run_at,last_run_at',
      order: 'week_start.desc',
      limit: String(parseLimit(req.query.limit))
    });

    const errors = [
      addUuidFilter(params, req.query, 'subject_person_id'),
      addUuidFilter(params, req.query, 'organization_id'),
      addUuidFilter(params, req.query, 'org_client_profile_id'),
      addTextFilter(params, req.query, 'user_id', 120),
      addTextFilter(params, req.query, 'source', 80)
    ].filter(Boolean);

    if (req.query.after) params.set('week_start', `gte.${String(req.query.after).slice(0, 10)}`);
    if (req.query.before) params.append('week_start', `lte.${String(req.query.before).slice(0, 10)}`);

    if (errors.length) return res.status(400).json({ error: 'invalid request', details: errors });

    const summaries = await supabaseFetch(`/${view}?${params.toString()}`);

    return res.status(200).json({
      ok: true,
      source: 'run-log-weekly-summaries',
      summaries,
      count: summaries.length
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
