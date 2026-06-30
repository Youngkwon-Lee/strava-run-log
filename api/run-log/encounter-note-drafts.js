import { buildEncounterNoteExport } from '../../lib/encounter-note-export.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const NOTE_FORMATS = new Set(['soap', 'dap', 'wellness_note', 'training_log']);
const STATUSES = new Set(['draft']);

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

function parseBody(req) {
  const body = req.body || {};
  return typeof body === 'object' && body !== null ? body : {};
}

function requireUuid(errors, body, field) {
  const value = body[field] === undefined || body[field] === null ? '' : String(body[field]).trim();
  if (!value) errors.push(`${field} is required`);
  else if (!UUID_RE.test(value)) errors.push(`${field} must be a UUID`);
}

function optionalEnum(errors, body, field, allowed) {
  const value = body[field] === undefined || body[field] === null ? '' : String(body[field]).trim();
  if (value && !allowed.has(value)) errors.push(`${field} must be one of ${[...allowed].join(', ')}`);
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });
    if (!isAuthorized(req)) return res.status(401).json({ error: 'unauthorized' });

    const body = parseBody(req);
    const errors = [];
    requireUuid(errors, body, 'encounterId');
    requireUuid(errors, body, 'organizationId');
    requireUuid(errors, body, 'subjectPersonId');
    requireUuid(errors, body, 'providerPersonId');
    optionalEnum(errors, body, 'noteFormat', NOTE_FORMATS);
    optionalEnum(errors, body, 'status', STATUSES);

    const text = String(body.editedNoteContent || body.noteContent || body.insight?.noteDraft || '').trim();
    if (!text) errors.push('editedNoteContent, noteContent, or insight.noteDraft is required');
    if (text.length > 8000) errors.push('note content must be 8000 characters or less');

    if (errors.length) return res.status(400).json({ error: 'invalid request', details: errors });

    const draftExport = buildEncounterNoteExport({
      encounterId: String(body.encounterId).trim(),
      organizationId: String(body.organizationId).trim(),
      subjectPersonId: String(body.subjectPersonId).trim(),
      providerPersonId: String(body.providerPersonId).trim(),
      insight: body.insight,
      editedNoteContent: body.editedNoteContent,
      noteContent: body.noteContent,
      noteFormat: body.noteFormat,
      status: body.status,
      isMedicalContext: body.isMedicalContext,
      requiresApproval: body.requiresApproval,
      generatedAt: new Date().toISOString()
    });

    return res.status(200).json({
      ok: true,
      source: 'encounter-note-draft-export',
      persisted: false,
      draftExport,
      message: 'Draft export generated. Persist it through the PhysioApp encounter note workflow after professional review.'
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}
