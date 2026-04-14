import { buildLiveCoaching } from '../../lib/coaching.js';
import { postDiscord } from '../../lib/discord.js';

const lastSentBySession = new Map();

function shouldSend(sessionId, cooldownSec = 90) {
  const now = Date.now();
  const prev = lastSentBySession.get(sessionId) || 0;
  if (now - prev < cooldownSec * 1000) return false;
  lastSentBySession.set(sessionId, now);
  return true;
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'method not allowed' });
    }

    const body = req.body || {};
    const sessionId = String(body.session_id || 'default');
    const metrics = {
      paceSec: Number(body.pace_sec || 0),
      hr: Number(body.hr || 0),
      distanceKm: Number(body.distance_km || 0),
      elapsedSec: Number(body.elapsed_sec || 0)
    };

    const coaching = buildLiveCoaching(metrics, {
      targetPaceSec: Number(process.env.COACH_TARGET_PACE_SEC || 370),
      maxHr: Number(process.env.COACH_MAX_HR || 175)
    });

    const force = Boolean(body.force);
    const sent = force || shouldSend(sessionId, Number(process.env.COACH_COOLDOWN_SEC || 90));

    if (sent) {
      const text = [
        '🎧 실시간 러닝 코칭',
        `- session: ${sessionId}`,
        `- pace ${metrics.paceSec ? Math.floor(metrics.paceSec / 60) + ':' + String(Math.round(metrics.paceSec % 60)).padStart(2, '0') : '-'} /km · HR ${metrics.hr || '-'} · ${metrics.distanceKm.toFixed(2)}km`,
        '',
        coaching
      ].join('\n');
      await postDiscord(text);
    }

    return res.status(200).json({ ok: true, sent, coaching });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
