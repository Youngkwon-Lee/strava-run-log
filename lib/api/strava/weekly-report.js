import {
  filterMinimumDistance,
  getAccessTokenForRequest,
  isRunActivity,
  listAthleteActivities,
  normalizeActivity,
  sortActivitiesNewestFirst,
  summarizeActivities
} from '../../strava.js';
import { postDiscord } from '../../discord.js';
import { filterStoredRuns, readStoredRuns, summarizeStoredRuns, upsertStoredRun } from '../../run-store.js';

function startOfWindow(days = 7) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d;
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    const after = Math.floor(startOfWindow(7).getTime() / 1000);
    const source = String(req.query.source || 'strava').trim().toLowerCase();

    let runs;
    let rollup;
    let authMode;
    let activityCount;
    let ignoredShortRunCount;

    if (source === 'stored') {
      authMode = 'run-store';
      runs = filterStoredRuns(await readStoredRuns(), {
        minDistanceKm: 0.05,
        after: new Date(after * 1000).toISOString()
      });
      rollup = summarizeStoredRuns(runs);
      activityCount = runs.length;
      ignoredShortRunCount = 0;
    } else {
      const tokenResult = await getAccessTokenForRequest(req, res);
      authMode = tokenResult.authMode;

      const activities = await listAthleteActivities(tokenResult.token, {
        after,
        perPage: 100,
        limit: 200,
        maxPages: 3
      });
      const allRuns = activities.filter(isRunActivity);
      runs = sortActivitiesNewestFirst(filterMinimumDistance(allRuns, 0.05).map(normalizeActivity));
      for (const run of runs) {
        await upsertStoredRun({
          ...run,
          source: 'strava',
          provider: 'strava',
          externalId: run.id
        });
      }
      rollup = summarizeActivities(runs);
      activityCount = activities.length;
      ignoredShortRunCount = allRuns.length - runs.length;
    }

    const movingSec = runs.reduce((sum, a) => sum + Number(a.movingTimeSec || 0), 0);
    const totalKm = runs.reduce((sum, a) => sum + Number(a.distanceMeters || 0), 0) / 1000;

    const moderateMin = Math.round(movingSec / 60);
    const whoMin = 150;
    const whoMax = 300;
    const progress = Math.min(100, Math.round((moderateMin / whoMin) * 100));

    const summary = {
      runCount: runs.length,
      totalKm: Number(totalKm.toFixed(2)),
      moderateMinutes: moderateMin,
      whoTargetMin: whoMin,
      whoTargetMax: whoMax,
      progressToMinPct: progress,
      status:
        moderateMin < whoMin
          ? 'below_minimum'
          : moderateMin <= whoMax
            ? 'in_recommended_range'
            : 'above_recommended_range',
      averagePace: rollup.averagePace,
      totalElevationGainMeters: rollup.totalElevationGainMeters || 0,
      ...(rollup.averageHeartrate ? { averageHeartrate: rollup.averageHeartrate } : {}),
      ...(rollup.averageCadence ? { averageCadence: rollup.averageCadence } : {}),
      ...(rollup.longestRun ? { longestRun: rollup.longestRun } : {})
    };

    if (String(req.query.send || '').toLowerCase() === 'true') {
      const text = [
        '📊 주간 운동 리포트 (WHO 기준)',
        `- 러닝 횟수: ${summary.runCount}회`,
        `- 총 거리: ${summary.totalKm}km`,
        `- 중강도 환산: ${summary.moderateMinutes}분`,
        `- WHO 권장: 150~300분/주`,
        `- 상태: ${summary.status}`
      ].join('\n');
      await postDiscord(text);
    }

    return res.status(200).json({
      ok: true,
      source: source === 'stored' ? 'stored' : 'strava',
      authMode,
      window: {
        days: 7,
        after,
        afterIso: new Date(after * 1000).toISOString(),
        minDistanceKm: 0.05
      },
      fetched: {
        activityCount,
        runCount: runs.length,
        ignoredShortRunCount
      },
      summary,
      runs
    });
  } catch (e) {
    return res.status(e.statusCode || 500).json({ error: e.message });
  }
}
