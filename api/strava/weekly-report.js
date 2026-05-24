import {
  filterMinimumDistance,
  getAccessTokenForRequest,
  isRunActivity,
  listAthleteActivities,
  normalizeActivity,
  sortActivitiesNewestFirst,
  summarizeActivities
} from '../../lib/strava.js';
import { postDiscord } from '../../lib/discord.js';

function startOfWindow(days = 7) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d;
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    const { token, authMode } = await getAccessTokenForRequest(req, res);
    const after = Math.floor(startOfWindow(7).getTime() / 1000);

    const activities = await listAthleteActivities(token, {
      after,
      perPage: 100,
      limit: 200,
      maxPages: 3
    });
    const allRuns = activities.filter(isRunActivity);
    const runs = sortActivitiesNewestFirst(filterMinimumDistance(allRuns, 0.05).map(normalizeActivity));
    const rollup = summarizeActivities(runs);

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
      source: 'strava',
      authMode,
      window: {
        days: 7,
        after,
        afterIso: new Date(after * 1000).toISOString(),
        minDistanceKm: 0.05
      },
      fetched: {
        activityCount: activities.length,
        runCount: runs.length,
        ignoredShortRunCount: allRuns.length - runs.length
      },
      summary,
      runs
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
