import encounterInsights from './encounter-insights.js';
import encounterNoteDrafts from './encounter-note-drafts.js';
import preflight from './preflight.js';
import promoteToActivitySession from './promote-to-activity-session.js';
import stateSnapshots from './state-snapshots.js';
import timeline from './timeline.js';
import weeklySummaries from './weekly-summaries.js';

const ROUTES = new Map([
  ['encounter-insights', encounterInsights],
  ['encounter-note-drafts', encounterNoteDrafts],
  ['preflight', preflight],
  ['promote-to-activity-session', promoteToActivitySession],
  ['state-snapshots', stateSnapshots],
  ['timeline', timeline],
  ['weekly-summaries', weeklySummaries]
]);

function routeKey(req) {
  const url = new URL(req.url || '/', 'https://run-log.local');
  const parts = url.pathname.split('/').filter(Boolean);
  const runLogIndex = parts.findIndex((part) => part === 'run-log');
  return runLogIndex >= 0 ? parts[runLogIndex + 1] : parts.at(-1);
}

export default async function handler(req, res) {
  const key = routeKey(req);
  const route = key ? ROUTES.get(key) : null;
  if (!route) return res.status(404).json({ error: 'run-log route not found' });
  return route(req, res);
}
