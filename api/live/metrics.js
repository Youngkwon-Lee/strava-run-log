import { buildLiveCoachingDecision } from '../../lib/coaching.js';
import { postDiscord } from '../../lib/discord.js';

const lastSentBySession = new Map();

function shouldSend(sessionId, cooldownSec = 90) {
  const now = Date.now();
  const prev = lastSentBySession.get(sessionId) || 0;
  if (now - prev < cooldownSec * 1000) return false;
  lastSentBySession.set(sessionId, now);
  return true;
}

function loadUserProfiles() {
  try {
    const raw = process.env.COACH_USER_PROFILES_JSON;
    if (!raw) return {};
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function resolveUserConfig(userId, readinessScore) {
  const profiles = loadUserProfiles();
  const profile = profiles[userId] || {};

  return {
    targetPaceSec: Number(profile.target_pace_sec ?? process.env.COACH_TARGET_PACE_SEC ?? 370),
    maxHr: Number(profile.max_hr ?? process.env.COACH_MAX_HR ?? 175),
    hrSustainedSec: Number(profile.hr_sustained_sec ?? process.env.COACH_HR_SUSTAINED_SEC ?? 120),
    cooldownSec: Number(profile.coaching_frequency_sec ?? process.env.COACH_COOLDOWN_SEC ?? 90),
    readinessScore: Number.isFinite(readinessScore) ? readinessScore : Number(profile.readiness_score)
  };
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'method not allowed' });
    }

    const body = req.body || {};
    const sessionId = String(body.session_id || 'default');
    const userId = String(body.user_id || 'default');
    const readinessScore = Number(body.readiness_score);

    const metrics = {
      paceSec: Number(body.pace_sec || 0),
      hr: Number(body.hr || 0),
      distanceKm: Number(body.distance_km || 0),
      elapsedSec: Number(body.elapsed_sec || 0),
      cadence: Number(body.cadence || 0),
      gapSec: Number(body.gap_sec || 0)
    };

    const cfg = resolveUserConfig(userId, readinessScore);
    const decision = buildLiveCoachingDecision(metrics, {
      targetPaceSec: cfg.targetPaceSec,
      maxHr: cfg.maxHr,
      hrSustainedSec: cfg.hrSustainedSec,
      readinessScore: cfg.readinessScore,
      nextCheckSec: cfg.cooldownSec
    });

    const force = Boolean(body.force);
    const sent = force || shouldSend(sessionId, cfg.cooldownSec);

    if (sent) {
      const icon = decision.severity === 'alert' ? '🚨' : decision.severity === 'warn' ? '⚠️' : '🎧';
      const text = [
        `${icon} 실시간 러닝 코칭`,
        `- user: ${userId} · session: ${sessionId}`,
        `- pace ${metrics.paceSec ? Math.floor(metrics.paceSec / 60) + ':' + String(Math.round(metrics.paceSec % 60)).padStart(2, '0') : '-'} /km · HR ${metrics.hr || '-'} · ${metrics.distanceKm.toFixed(2)}km`,
        `- action: ${decision.action} · severity: ${decision.severity}`,
        '',
        decision.text
      ].join('\n');
      await postDiscord(text);
    }

    return res.status(200).json({
      ok: true,
      sent,
      coaching: decision.text,
      severity: decision.severity,
      action: decision.action,
      nextCheckSec: decision.nextCheckSec,
      adjustedTargetPaceSec: decision.adjustedTargetPaceSec
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
