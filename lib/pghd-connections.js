import { supabaseFetch } from './supabase-rest.js';

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

export function normalizePghdProvider(source) {
  const value = String(source || '').trim().toLowerCase().replace(/_/g, '-');
  return value;
}

export function toPghdStorageProvider(source) {
  return normalizePghdProvider(source).replace(/-/g, '_');
}

export function pghdProviderAliases(source) {
  const provider = normalizePghdProvider(source);
  const aliases = new Set([provider, toPghdStorageProvider(provider)]);
  return [...aliases].filter(Boolean);
}

function connectionTable() {
  return process.env.PGHD_CONNECTIONS_TABLE || 'pghd_connections';
}

function personColumn() {
  return process.env.PGHD_CONNECTIONS_PERSON_COLUMN || 'person_id';
}

export function getPghdConnectionsTable() {
  return connectionTable();
}

export function getPghdConnectionsPersonColumn() {
  return personColumn();
}

function buildProviderUserCandidates(run = {}) {
  return [...new Set([
    run.providerUserId,
    run.provider_user_id,
    run.userId,
    run.user_id,
    run.athleteId,
    run.athlete_id,
    run.raw?.providerUserId,
    run.raw?.userId
  ]
    .map((value) => (value === undefined || value === null ? '' : String(value).trim()))
    .filter(Boolean))];
}

export async function resolvePghdConnectionForRun(run = {}) {
  if (run.subjectPersonId || run.subject_person_id) {
    return {
      subjectPersonId: run.subjectPersonId || run.subject_person_id,
      connectionResolved: false,
      reason: 'already-mapped'
    };
  }

  const providerValues = pghdProviderAliases(run.provider || run.source);
  const providerUserIds = buildProviderUserCandidates(run);
  if (!providerValues.length || !providerUserIds.length) {
    return { connectionResolved: false, reason: 'missing-provider-or-user' };
  }

  const params = new URLSearchParams({
    select: `id,${personColumn()},provider,provider_user_id,connection_status,metadata`,
    provider: `in.(${providerValues.map(encodeURIComponent).join(',')})`,
    provider_user_id: `in.(${providerUserIds.map(encodeURIComponent).join(',')})`,
    limit: '2'
  });

  const rows = await supabaseFetch(`/${connectionTable()}?${params.toString()}`);
  if (!rows?.length) return { connectionResolved: false, reason: 'not-found' };
  if (rows.length > 1) return { connectionResolved: false, reason: 'ambiguous', matches: rows.length };

  const row = rows[0];
  const subjectPersonId = row[personColumn()];
  if (!subjectPersonId) return { connectionResolved: false, reason: 'missing-person-id' };

  return compactObject({
    connectionResolved: true,
    connectionId: row.id,
    subjectPersonId,
    provider: row.provider,
    providerUserId: row.provider_user_id,
    connectionStatus: row.connection_status
  });
}

export async function attachPghdConnectionToRun(run = {}) {
  const resolved = await resolvePghdConnectionForRun(run);
  if (!resolved.connectionResolved) return { run, connection: resolved };

  return {
    run: compactObject({
      ...run,
      subjectPersonId: run.subjectPersonId || resolved.subjectPersonId,
      pghdConnectionId: resolved.connectionId,
      providerUserId: run.providerUserId || resolved.providerUserId
    }),
    connection: resolved
  };
}
