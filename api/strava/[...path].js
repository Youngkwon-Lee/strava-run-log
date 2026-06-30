import activities from '../../lib/api/strava/activities.js';
import callback from '../../lib/api/strava/callback.js';
import connect from '../../lib/api/strava/connect.js';
import disconnect from '../../lib/api/strava/disconnect.js';
import me from '../../lib/api/strava/me.js';
import webhook from '../../lib/api/strava/webhook.js';
import weeklyReport from '../../lib/api/strava/weekly-report.js';

const ROUTES = new Map([
  ['activities', activities],
  ['callback', callback],
  ['connect', connect],
  ['disconnect', disconnect],
  ['me', me],
  ['webhook', webhook],
  ['weekly-report', weeklyReport]
]);

function routeKey(req) {
  const url = new URL(req.url || '/', 'https://run-log.local');
  const parts = url.pathname.split('/').filter(Boolean);
  const stravaIndex = parts.findIndex((part) => part === 'strava');
  return stravaIndex >= 0 ? parts[stravaIndex + 1] : parts.at(-1);
}

export default async function handler(req, res) {
  const key = routeKey(req);
  const route = key ? ROUTES.get(key) : null;
  if (!route) return res.status(404).json({ error: 'strava route not found' });
  return route(req, res);
}
