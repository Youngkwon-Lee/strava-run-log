import {
  filterMinimumDistance,
  getActivityDetail,
  getActivityStreams,
  getAccessTokenForRequest,
  isRunActivity,
  listAthleteActivities,
  normalizeActivity,
  sortActivitiesNewestFirst,
  summarizeActivities
} from '../../lib/strava.js';
import { filterStoredRuns, readStoredRuns, summarizeStoredRuns, upsertStoredRun } from '../../lib/run-store.js';

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  if (typeof value === 'boolean') return value;
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'y'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'n'].includes(normalized)) return false;
  return fallback;
}

function parseInteger(value, { min, max, fallback }) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

function parseNumber(value, { min, max, fallback }) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function unixSecondsFromQuery(value) {
  if (!value) return undefined;
  const numeric = Number(value);
  if (Number.isFinite(numeric)) return Math.trunc(numeric);

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return undefined;
  return Math.floor(date.getTime() / 1000);
}

function getWindow(query = {}) {
  const days = parseInteger(query.days, { min: 1, max: 365, fallback: 30 });
  const nowSec = Math.floor(Date.now() / 1000);
  const after = unixSecondsFromQuery(query.after) ?? nowSec - days * 24 * 60 * 60;
  const before = unixSecondsFromQuery(query.before);

  return {
    days,
    after,
    before,
    afterIso: new Date(after * 1000).toISOString(),
    beforeIso: before ? new Date(before * 1000).toISOString() : undefined
  };
}

async function enrichActivity(activity, token, opts) {
  const detail = opts.includeDetails ? await getActivityDetail(activity.id, token) : activity;

  let streams;
  let streamError;
  if (opts.includeStreams) {
    try {
      streams = await getActivityStreams(activity.id, token);
    } catch (e) {
      streamError = e.message;
    }
  }

  return normalizeActivity(detail, {
    streams,
    streamError,
    includeStreams: opts.includeStreams
  });
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    const query = req.query || {};
    const limit = parseInteger(query.limit, { min: 1, max: 100, fallback: 20 });
    const perPage = parseInteger(query.per_page, { min: 1, max: 200, fallback: 100 });
    const includeDetails = parseBoolean(query.details, true);
    const includeStreams = parseBoolean(query.streams, false);
    const includeShort = parseBoolean(query.include_short, false);
    const minDistanceKm = includeShort
      ? 0
      : parseNumber(query.min_distance_km, { min: 0, max: 5, fallback: 0.05 });
    const window = getWindow(query);
    const source = String(query.source || 'strava').trim().toLowerCase();

    if (source === 'stored') {
      const storedRuns = filterStoredRuns(await readStoredRuns(), {
        minDistanceKm,
        after: window.afterIso,
        before: window.beforeIso
      }).slice(0, limit);

      return res.status(200).json({
        ok: true,
        source: 'stored',
        authMode: 'run-store',
        query: {
          ...window,
          limit,
          includeShort,
          minDistanceKm
        },
        fetched: {
          activityCount: storedRuns.length,
          runCount: storedRuns.length,
          ignoredShortRunCount: 0
        },
        summary: summarizeStoredRuns(storedRuns),
        activities: storedRuns
      });
    }

    const { token, authMode } = await getAccessTokenForRequest(req, res);
    const activities = await listAthleteActivities(token, {
      after: window.after,
      before: window.before,
      perPage,
      limit: Math.max(limit * 2, perPage),
      maxPages: 5
    });

    const allRuns = activities.filter(isRunActivity);
    const filteredRuns = filterMinimumDistance(allRuns, minDistanceKm);
    const runs = sortActivitiesNewestFirst(filteredRuns).slice(0, limit);
    const enriched = [];
    for (const run of runs) {
      const normalized = await enrichActivity(run, token, { includeDetails, includeStreams });
      enriched.push(normalized);
      await upsertStoredRun({
        ...normalized,
        source: 'strava',
        provider: 'strava',
        externalId: normalized.id
      });
    }
    const sorted = sortActivitiesNewestFirst(enriched);

    return res.status(200).json({
      ok: true,
      source: 'strava',
      authMode,
      note: '비공개/Only You 활동까지 가져오려면 Strava OAuth scope에 activity:read_all이 필요합니다.',
      query: {
        ...window,
        limit,
        includeDetails,
        includeStreams,
        includeShort,
        minDistanceKm
      },
      fetched: {
        activityCount: activities.length,
        runCount: sorted.length,
        ignoredShortRunCount: allRuns.length - filteredRuns.length
      },
      summary: summarizeActivities(sorted),
      activities: sorted
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
