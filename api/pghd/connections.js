import {
  getPghdConnectionsPersonColumn,
  getPghdConnectionsTable,
  normalizePghdProvider
} from '../../lib/pghd-connections.js';
import { assertSimpleIdentifier, supabaseFetch } from '../../lib/supabase-rest.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PROVIDERS = new Set(['apple-health', 'strava', 'garmin', 'file-import', 'samsung-health', 'nike-run-club']);

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

function text(value, field, { required = true, maxLength = 200 } = {}) {
  const normalized = value === undefined || value === null ? '' : String(value).trim();
  if (!normalized && required) return { error: `${field} is required` };
  if (normalized.length > maxLength) return { error: `${field} must be ${maxLength} characters or less` };
  return { value: normalized || null };
}

function uuid(value, field, { required = true } = {}) {
  const normalized = value === undefined || value === null ? '' : String(value).trim();
  if (!normalized && required) return { error: `${field} is required` };
  if (!normalized) return { value: null };
  if (!UUID_RE.test(normalized)) return { error: `${field} must be a UUID` };
  return { value: normalized };
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function parseMetadata(value) {
  if (value === undefined || value === null || value === '') return { value: null };
  if (typeof value === 'object' && !Array.isArray(value)) return { value };
  return { error: 'metadata must be an object' };
}

function tableInfo() {
  const table = getPghdConnectionsTable();
  const person = getPghdConnectionsPersonColumn();
  assertSimpleIdentifier(table, 'PGHD_CONNECTIONS_TABLE');
  assertSimpleIdentifier(person, 'PGHD_CONNECTIONS_PERSON_COLUMN');
  return { table, person };
}

async function listConnections(query) {
  const { table, person } = tableInfo();
  const params = new URLSearchParams({
    select: `id,${person},provider,provider_user_id,connection_status,last_sync_at,sync_frequency_hours,metadata,created_at,updated_at`,
    order: 'updated_at.desc',
    limit: String(Math.min(200, Math.max(1, Number(query.limit || 50))))
  });

  const personId = uuid(query.person_id, 'person_id', { required: false });
  if (personId.error) return { errors: [personId.error] };
  if (personId.value) params.set(person, `eq.${personId.value}`);

  const provider = text(query.provider, 'provider', { required: false, maxLength: 80 });
  if (provider.error) return { errors: [provider.error] };
  if (provider.value) params.set('provider', `eq.${normalizePghdProvider(provider.value)}`);

  const providerUserId = text(query.provider_user_id, 'provider_user_id', { required: false, maxLength: 200 });
  if (providerUserId.error) return { errors: [providerUserId.error] };
  if (providerUserId.value) params.set('provider_user_id', `eq.${providerUserId.value}`);

  return { connections: await supabaseFetch(`/${table}?${params.toString()}`) };
}

async function upsertConnection(body) {
  const { table, person } = tableInfo();
  const errors = [];
  const collect = (result) => {
    if (result.error) errors.push(result.error);
    return result.value;
  };

  const personId = collect(uuid(body.person_id, 'person_id'));
  const provider = normalizePghdProvider(collect(text(body.provider, 'provider', { maxLength: 80 })));
  const providerUserId = collect(text(body.provider_user_id, 'provider_user_id', { maxLength: 200 }));
  const status = collect(text(body.connection_status, 'connection_status', { required: false, maxLength: 40 })) || 'active';
  const metadata = collect(parseMetadata(body.metadata));

  if (provider && !PROVIDERS.has(provider)) {
    errors.push(`provider must be one of: ${Array.from(PROVIDERS).join(', ')}`);
  }
  if (errors.length) return { errors };

  const payload = compactObject({
    [person]: personId,
    provider,
    provider_user_id: providerUserId,
    connection_status: status,
    metadata
  });

  const params = new URLSearchParams({ on_conflict: `${person},provider` });
  const rows = await supabaseFetch(`/${table}?${params.toString()}`, {
    method: 'POST',
    headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
    body: JSON.stringify(payload)
  });

  return { connection: Array.isArray(rows) ? rows[0] : null };
}

export default async function handler(req, res) {
  try {
    if (!['GET', 'POST'].includes(req.method)) return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    if (req.method === 'GET') {
      const result = await listConnections(req.query || {});
      if (result.errors) return res.status(400).json({ error: 'invalid request', details: result.errors });
      return res.status(200).json({
        ok: true,
        connections: result.connections,
        count: result.connections.length
      });
    }

    const result = await upsertConnection(req.body || {});
    if (result.errors) return res.status(400).json({ error: 'invalid request', details: result.errors });
    return res.status(200).json({
      ok: true,
      connection: result.connection
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
