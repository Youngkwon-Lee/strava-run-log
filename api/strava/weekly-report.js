import { refreshTokenIfNeeded } from '../../lib/strava.js';
import { postDiscord } from '../../lib/discord.js';

function startOfWindow(days = 7) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d;
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    const token = await refreshTokenIfNeeded();
    const after = Math.floor(startOfWindow(7).getTime() / 1000);

    const r = await fetch(`https://www.strava.com/api/v3/athlete/activities?after=${after}&per_page=100`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    if (!r.ok) throw new Error(`strava activities failed: ${r.status}`);
    const activities = await r.json();

    const runs = activities.filter((a) => a.type === 'Run' || a.sport_type === 'Run');
    const movingSec = runs.reduce((sum, a) => sum + Number(a.moving_time || 0), 0);
    const totalKm = runs.reduce((sum, a) => sum + Number(a.distance || 0), 0) / 1000;

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
            : 'above_recommended_range'
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

    return res.status(200).json({ ok: true, summary });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
