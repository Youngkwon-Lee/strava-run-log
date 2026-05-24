import { consumeOAuthState, getPublicOrigin, setStravaSession, timingSafeStringEqual } from '../../lib/session.js';
import { exchangeStravaAuthorizationCode } from '../../lib/strava.js';

function withQuery(path, values) {
  const url = new URL(path, 'https://local.invalid');
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== null && value !== '') url.searchParams.set(key, String(value));
  }
  return `${url.pathname}${url.search}`;
}

function redirect(res, status, url) {
  if (typeof res.redirect === 'function') return res.redirect(status, url);
  res.statusCode = status;
  res.setHeader('Location', url);
  return res.end?.();
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    const savedState = consumeOAuthState(req, res);
    const returnTo = savedState?.returnTo || '/settings.html';

    if (req.query?.error) {
      return redirect(res, 302, withQuery(returnTo, { strava: 'denied', error: req.query.error }));
    }

    if (!savedState?.state || !timingSafeStringEqual(savedState.state, req.query?.state)) {
      return redirect(res, 302, withQuery('/settings.html', { strava: 'state_error' }));
    }

    const code = String(req.query?.code || '');
    if (!code) return redirect(res, 302, withQuery(returnTo, { strava: 'missing_code' }));

    const origin = getPublicOrigin(req);
    const tokenResponse = await exchangeStravaAuthorizationCode(code, `${origin}/api/strava/callback`);
    setStravaSession(req, res, tokenResponse);

    return redirect(res, 302, withQuery(returnTo, { strava: 'connected' }));
  } catch (e) {
    return redirect(res, 302, withQuery('/settings.html', { strava: 'error', message: e.message }));
  }
}
