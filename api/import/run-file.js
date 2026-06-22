import { parseRunFile } from '../../lib/run-file-import.js';
import { upsertStoredRun } from '../../lib/run-store.js';

function getHeader(req, name) {
  const headers = req.headers || {};
  return headers[name] || headers[name.toLowerCase()] || headers[name.toUpperCase()];
}

function verifyImportRequest(req, body) {
  const token = process.env.IMPORT_API_TOKEN;
  if (!token) return { ok: true };

  const auth = String(getHeader(req, 'authorization') || '');
  const bearer = auth.match(/^Bearer\s+(.+)$/i)?.[1];
  const headerToken = getHeader(req, 'x-import-token');
  const bodyToken = body?.import_token;
  const submitted = String(bearer || headerToken || bodyToken || '');

  if (submitted && submitted === token) return { ok: true };
  return { ok: false, statusCode: 401, error: 'unauthorized' };
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });

    const body = req.body || {};
    const auth = verifyImportRequest(req, body);
    if (!auth.ok) return res.status(auth.statusCode).json({ error: auth.error });

    const run = parseRunFile(body);
    const stored = await upsertStoredRun(run);

    return res.status(200).json({
      ok: true,
      source: 'file-import',
      id: run.externalId,
      summary: {
        name: run.name,
        fileFormat: run.fileFormat,
        distanceKm: run.distanceKm,
        movingTime: run.movingTime,
        pace: run.pace,
        startDate: run.startDate,
        routePointCount: run.routePointCount
      },
      stored: {
        inserted: stored.inserted,
        count: stored.count
      }
    });
  } catch (e) {
    if (e.code === 'UNSUPPORTED_FIT') {
      return res.status(415).json({ error: e.message });
    }
    return res.status(400).json({ error: e.message });
  }
}
