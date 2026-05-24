import { createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual } from 'node:crypto';

const COOKIE_PREFIX = 'strava_run_log';
const SESSION_COOKIE = `${COOKIE_PREFIX}_session`;
const STATE_COOKIE = `${COOKIE_PREFIX}_oauth_state`;
const SESSION_MAX_AGE_SEC = 60 * 60 * 24 * 180;
const STATE_MAX_AGE_SEC = 60 * 10;

function getSessionSecret() {
  const secret =
    process.env.STRAVA_SESSION_SECRET ||
    process.env.STRAVA_CLIENT_SECRET ||
    process.env.LIVE_METRICS_TOKEN ||
    process.env.STRAVA_REFRESH_TOKEN;

  if (!secret) {
    throw new Error('missing STRAVA_SESSION_SECRET for OAuth session cookies');
  }
  return createHash('sha256').update(String(secret)).digest();
}

function b64url(buffer) {
  return Buffer.from(buffer).toString('base64url');
}

function fromB64url(value) {
  return Buffer.from(String(value || ''), 'base64url');
}

function encrypt(value) {
  const key = getSessionSecret();
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const plaintext = Buffer.from(JSON.stringify(value), 'utf8');
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `v1.${b64url(iv)}.${b64url(tag)}.${b64url(encrypted)}`;
}

function decrypt(value) {
  try {
    const [version, ivRaw, tagRaw, encryptedRaw] = String(value || '').split('.');
    if (version !== 'v1' || !ivRaw || !tagRaw || !encryptedRaw) return null;

    const key = getSessionSecret();
    const decipher = createDecipheriv('aes-256-gcm', key, fromB64url(ivRaw));
    decipher.setAuthTag(fromB64url(tagRaw));
    const decrypted = Buffer.concat([decipher.update(fromB64url(encryptedRaw)), decipher.final()]);
    return JSON.parse(decrypted.toString('utf8'));
  } catch {
    return null;
  }
}

function parseCookies(req) {
  const header = req?.headers?.cookie || req?.headers?.Cookie || '';
  return Object.fromEntries(
    String(header)
      .split(';')
      .map((part) => part.trim())
      .filter(Boolean)
      .map((part) => {
        const idx = part.indexOf('=');
        if (idx === -1) return [part, ''];
        return [part.slice(0, idx), decodeURIComponent(part.slice(idx + 1))];
      })
  );
}

function isLocalhost(req) {
  const host = String(req?.headers?.host || '').toLowerCase();
  return host.startsWith('localhost') || host.startsWith('127.0.0.1') || host.startsWith('[::1]');
}

function serializeCookie(name, value, opts = {}) {
  const parts = [
    `${name}=${encodeURIComponent(value)}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    `Max-Age=${Number(opts.maxAgeSec ?? SESSION_MAX_AGE_SEC)}`
  ];

  if (opts.secure !== false) parts.push('Secure');
  return parts.join('; ');
}

function appendSetCookie(res, value) {
  const prev = res.getHeader?.('Set-Cookie');
  const next = prev ? [prev].flat().concat(value) : value;
  res.setHeader('Set-Cookie', next);
}

function setEncryptedCookie(req, res, name, value, maxAgeSec) {
  appendSetCookie(
    res,
    serializeCookie(name, encrypt(value), {
      maxAgeSec,
      secure: !isLocalhost(req)
    })
  );
}

function clearCookie(req, res, name) {
  appendSetCookie(
    res,
    serializeCookie(name, '', {
      maxAgeSec: 0,
      secure: !isLocalhost(req)
    })
  );
}

function safeReturnTo(value) {
  const raw = String(value || '/settings.html');
  if (!raw.startsWith('/') || raw.startsWith('//')) return '/settings.html';
  return raw;
}

function publicAthlete(athlete) {
  if (!athlete) return null;
  return {
    id: athlete.id,
    username: athlete.username,
    firstname: athlete.firstname,
    lastname: athlete.lastname,
    city: athlete.city,
    state: athlete.state,
    country: athlete.country,
    sex: athlete.sex,
    profile: athlete.profile,
    profileMedium: athlete.profile_medium || athlete.profileMedium
  };
}

export function timingSafeStringEqual(a, b) {
  const left = Buffer.from(String(a || ''));
  const right = Buffer.from(String(b || ''));
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

export function createOAuthState(req, res, returnTo = '/settings.html') {
  const state = b64url(randomBytes(24));
  setEncryptedCookie(
    req,
    res,
    STATE_COOKIE,
    {
      state,
      returnTo: safeReturnTo(returnTo),
      createdAt: new Date().toISOString()
    },
    STATE_MAX_AGE_SEC
  );
  return state;
}

export function consumeOAuthState(req, res) {
  const cookies = parseCookies(req);
  const state = decrypt(cookies[STATE_COOKIE]);
  clearCookie(req, res, STATE_COOKIE);
  return state;
}

export function setStravaSession(req, res, tokenResponse) {
  const session = {
    provider: 'strava',
    connectedAt: new Date().toISOString(),
    accessToken: tokenResponse.access_token,
    refreshToken: tokenResponse.refresh_token,
    expiresAt: tokenResponse.expires_at,
    scope: tokenResponse.scope || '',
    athlete: publicAthlete(tokenResponse.athlete)
  };

  setEncryptedCookie(req, res, SESSION_COOKIE, session, SESSION_MAX_AGE_SEC);
  return session;
}

export function getStravaSession(req) {
  const cookies = parseCookies(req);
  const session = decrypt(cookies[SESSION_COOKIE]);
  if (!session?.refreshToken && !session?.accessToken) return null;
  return session;
}

export function clearStravaSession(req, res) {
  clearCookie(req, res, SESSION_COOKIE);
}

export function publicStravaSession(session) {
  if (!session) return null;
  return {
    connected: true,
    provider: 'strava',
    connectedAt: session.connectedAt,
    expiresAt: session.expiresAt,
    scope: session.scope || '',
    athlete: session.athlete || null,
    hasActivityReadAll: String(session.scope || '').split(/[,\s]+/).includes('activity:read_all')
  };
}

export function getPublicOrigin(req) {
  const host = req?.headers?.['x-forwarded-host'] || req?.headers?.host;
  if (!host) return process.env.STRAVA_PUBLIC_URL || process.env.PUBLIC_BASE_URL || 'http://localhost:3000';

  const configured = process.env.STRAVA_PUBLIC_URL || process.env.PUBLIC_BASE_URL;
  if (configured && !String(host).includes('localhost')) return configured.replace(/\/$/, '');

  const proto = req?.headers?.['x-forwarded-proto'] || (isLocalhost(req) ? 'http' : 'https');
  return `${proto}://${host}`;
}

export function getSessionCookieName() {
  return SESSION_COOKIE;
}
