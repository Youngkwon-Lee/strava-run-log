import { buildCoachingComment, getActivityDetail, refreshTokenIfNeeded, summarizeActivity } from '../../lib/strava.js';

const VERIFY_TOKEN = process.env.STRAVA_VERIFY_TOKEN;

async function postDiscord(text) {
  const base = process.env.DISCORD_WEBHOOK_URL;
  if (!base) return;

  const threadId = process.env.DISCORD_THREAD_ID;
  const url = threadId
    ? `${base}${base.includes('?') ? '&' : '?'}thread_id=${encodeURIComponent(threadId)}`
    : base;

  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: text })
  });
}

export default async function handler(req, res) {
  try {
    if (req.method === 'GET') {
      const mode = req.query['hub.mode'];
      const token = req.query['hub.verify_token'];
      const challenge = req.query['hub.challenge'];
      if (mode === 'subscribe' && token === VERIFY_TOKEN) {
        return res.status(200).json({ 'hub.challenge': challenge });
      }
      return res.status(403).json({ error: 'verify failed' });
    }

    if (req.method === 'POST') {
      const evt = req.body || {};
      if (evt.object_type !== 'activity' || evt.aspect_type === 'delete') {
        return res.status(200).json({ ok: true, ignored: true });
      }

      const token = await refreshTokenIfNeeded();
      const detail = await getActivityDetail(evt.object_id, token);
      const s = summarizeActivity(detail);
      const coaching = buildCoachingComment(detail, {
        targetPaceSec: Number(process.env.COACH_TARGET_PACE_SEC || 370),
        targetRpe: process.env.COACH_TARGET_RPE || '6~7'
      });

      const txt = [
        '🏃 새 러닝 감지',
        `- ${s.title}`,
        `- ${s.km}km · ${s.moving} · ${s.pace} · 상승 ${s.elev}m`,
        '',
        coaching
      ].join('\n');
      await postDiscord(txt);

      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'method not allowed' });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
