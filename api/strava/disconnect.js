import { clearStravaSession, getStravaSession } from '../../lib/session.js';

async function deauthorize(session) {
  if (!session?.accessToken) return;
  await fetch('https://www.strava.com/oauth/deauthorize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ access_token: session.accessToken })
  }).catch(() => {});
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });

    const session = getStravaSession(req);
    await deauthorize(session);
    clearStravaSession(req, res);
    return res.status(200).json({ ok: true, disconnected: Boolean(session) });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
