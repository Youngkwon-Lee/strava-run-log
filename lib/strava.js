export async function refreshTokenIfNeeded() {
  const now = Math.floor(Date.now() / 1000);
  const exp = Number(process.env.STRAVA_TOKEN_EXPIRES_AT || 0);
  if (process.env.STRAVA_ACCESS_TOKEN && exp > now + 120) return process.env.STRAVA_ACCESS_TOKEN;

  const body = new URLSearchParams({
    client_id: process.env.STRAVA_CLIENT_ID,
    client_secret: process.env.STRAVA_CLIENT_SECRET,
    grant_type: 'refresh_token',
    refresh_token: process.env.STRAVA_REFRESH_TOKEN
  });

  const r = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body
  });
  if (!r.ok) throw new Error(`refresh failed: ${r.status}`);
  const j = await r.json();

  process.env.STRAVA_ACCESS_TOKEN = j.access_token;
  process.env.STRAVA_REFRESH_TOKEN = j.refresh_token;
  process.env.STRAVA_TOKEN_EXPIRES_AT = String(j.expires_at);
  return j.access_token;
}

export async function getActivityDetail(activityId, token) {
  const r = await fetch(`https://www.strava.com/api/v3/activities/${activityId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (!r.ok) throw new Error(`activity detail failed: ${r.status}`);
  return r.json();
}

export function summarizeActivity(d) {
  const km = ((d.distance || 0) / 1000).toFixed(2);
  const sec = d.moving_time || 0;
  const mm = Math.floor(sec / 60);
  const ss = sec % 60;
  const paceSec = d.distance ? sec / (d.distance / 1000) : 0;
  const pm = Math.floor(paceSec / 60);
  const ps = Math.round(paceSec % 60);
  return {
    title: d.name || 'Run',
    km,
    moving: `${mm}:${String(ss).padStart(2, '0')}`,
    pace: `${pm}:${String(ps).padStart(2, '0')}/km`,
    elev: d.total_elevation_gain ?? 0
  };
}
