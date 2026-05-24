import { getStravaSession, publicStravaSession } from '../../lib/session.js';

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    const session = publicStravaSession(getStravaSession(req));
    return res.status(200).json({
      ok: true,
      connected: Boolean(session),
      session,
      serverFallbackConfigured: Boolean(process.env.STRAVA_REFRESH_TOKEN)
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
