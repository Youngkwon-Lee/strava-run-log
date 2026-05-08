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

function getHeader(req, name) {
  const headers = req.headers || {};
  const target = name.toLowerCase();
  const key = Object.keys(headers).find((headerName) => headerName.toLowerCase() === target);
  return key ? headers[key] : undefined;
}

function isAuthorized(req) {
  const expected = process.env.LIVE_METRICS_TOKEN;
  if (!expected) return true;

  const auth = String(getHeader(req, 'authorization') || '');
  const bearer = auth.startsWith('Bearer ') ? auth.slice('Bearer '.length).trim() : '';
  const headerToken = String(getHeader(req, 'x-live-metrics-token') || getHeader(req, 'x-live-token') || '').trim();

  return bearer === expected || headerToken === expected;
}

function parseTextField(body, field, fallback, maxLength = 120) {
  const raw = body[field];
  const value = raw === undefined || raw === null || raw === '' ? fallback : String(raw).trim();
  if (!value) return { error: `${field} must not be empty` };
  if (value.length > maxLength) return { error: `${field} must be ${maxLength} characters or less` };
  return { value };
}

function parseNumberField(body, field, { min, max, defaultValue = 0 }) {
  const raw = body[field];
  if (raw === undefined || raw === null || raw === '') return { value: defaultValue };

  const value = Number(raw);
  if (!Number.isFinite(value)) return { error: `${field} must be a finite number` };
  if (value < min || value > max) return { error: `${field} must be between ${min} and ${max}` };
  return { value };
}

function parseBooleanField(body, field, defaultValue = false) {
  const raw = body[field];
  if (raw === undefined || raw === null || raw === '') return { value: defaultValue };
  if (typeof raw === 'boolean') return { value: raw };
  if (raw === 1 || raw === '1') return { value: true };
  if (raw === 0 || raw === '0') return { value: false };
  if (typeof raw === 'string') {
    const normalized = raw.trim().toLowerCase();
    if (normalized === 'true') return { value: true };
    if (normalized === 'false') return { value: false };
  }
  return { error: `${field} must be a boolean` };
}

function shouldPostDiscord(sessionId) {
  if (!String(sessionId).startsWith('sim-')) return true;
  return String(process.env.ALLOW_SIM_DISCORD_POSTS || '').trim().toLowerCase() === 'true';
}

function validateLiveMetricsPayload(body) {
  const errors = [];
  const collect = (result) => {
    if (result.error) errors.push(result.error);
    return result.value;
  };

  const sessionId = collect(parseTextField(body, 'session_id', 'default'));
  const userId = collect(parseTextField(body, 'user_id', 'default', 80));
  const force = collect(parseBooleanField(body, 'force', false));
  const readinessScore = collect(parseNumberField(body, 'readiness_score', {
    min: 0,
    max: 100,
    defaultValue: Number.NaN
  }));

  const metrics = {
    paceSec: collect(parseNumberField(body, 'pace_sec', { min: 0, max: 1800 })),
    hr: collect(parseNumberField(body, 'hr', { min: 0, max: 240 })),
    distanceKm: collect(parseNumberField(body, 'distance_km', { min: 0, max: 200 })),
    elapsedSec: collect(parseNumberField(body, 'elapsed_sec', { min: 0, max: 86400 })),
    cadence: collect(parseNumberField(body, 'cadence', { min: 0, max: 260 })),
    gapSec: collect(parseNumberField(body, 'gap_sec', { min: 0, max: 1800 }))
  };

  return errors.length
    ? { errors }
    : { sessionId, userId, force, readinessScore, metrics };
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

    if (!isAuthorized(req)) {
      return res.status(401).json({ error: 'unauthorized' });
    }

    const body = req.body || {};
    const parsed = validateLiveMetricsPayload(body);
    if (parsed.errors) {
      return res.status(400).json({ error: 'invalid request', details: parsed.errors });
    }

    const { sessionId, userId, readinessScore, metrics, force } = parsed;

    const cfg = resolveUserConfig(userId, readinessScore);
    const decision = buildLiveCoachingDecision(metrics, {
      targetPaceSec: cfg.targetPaceSec,
      maxHr: cfg.maxHr,
      hrSustainedSec: cfg.hrSustainedSec,
      readinessScore: cfg.readinessScore,
      nextCheckSec: cfg.cooldownSec
    });

    const canPostDiscord = shouldPostDiscord(sessionId);
    const sent = canPostDiscord && (force || shouldSend(sessionId, cfg.cooldownSec));

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
