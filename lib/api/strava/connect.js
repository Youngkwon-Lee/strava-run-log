import { createOAuthState, getPublicOrigin } from '../../session.js';

const STRAVA_SCOPE = 'read,activity:read,activity:read_all';

function redirect(res, status, url) {
  if (typeof res.redirect === 'function') return res.redirect(status, url);
  res.statusCode = status;
  res.setHeader('Location', url);
  return res.end?.();
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });
    if (!process.env.STRAVA_CLIENT_ID) return res.status(500).json({ error: 'missing STRAVA_CLIENT_ID' });

    const origin = getPublicOrigin(req);
    const returnTo = req.query?.return_to || '/settings.html';
    const state = createOAuthState(req, res, returnTo);
    const redirectUri = `${origin}/api/strava/callback`;
    const authUrl = new URL('https://www.strava.com/oauth/authorize');
    authUrl.searchParams.set('client_id', process.env.STRAVA_CLIENT_ID);
    authUrl.searchParams.set('redirect_uri', redirectUri);
    authUrl.searchParams.set('response_type', 'code');
    authUrl.searchParams.set('approval_prompt', String(req.query?.approval_prompt || 'force'));
    authUrl.searchParams.set('scope', STRAVA_SCOPE);
    authUrl.searchParams.set('state', state);

    return redirect(res, 302, authUrl.toString());
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
