import { buildPostRunCoaching } from '../../lib/coaching.js';
import { postDiscord } from '../../lib/discord.js';
import {
  buildAppleHealthDiscordMessage,
  summarizeAppleHealthRun,
  toCoachingDetail,
  validateAppleHealthPayload,
  verifyAppleHealthRequest
} from '../../lib/apple-health.js';
import { normalizeAppleHealthRunForStore, upsertStoredRun } from '../../lib/run-store.js';

function shouldSendToDiscord(body) {
  if (body?.send_to_discord === false || body?.send_to_discord === 'false' || body?.send_to_discord === 0 || body?.send_to_discord === '0') {
    return false;
  }
  return true;
}

export default async function handler(req, res) {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'method not allowed' });
    }

    const body = req.body || {};
    const auth = verifyAppleHealthRequest(req, body);
    if (auth.error) {
      return res.status(auth.statusCode || 401).json({ error: auth.error });
    }

    const parsed = validateAppleHealthPayload(body);
    if (parsed.errors) {
      return res.status(400).json({ error: 'invalid request', details: parsed.errors });
    }

    const summary = summarizeAppleHealthRun(parsed);
    const coaching = buildPostRunCoaching(toCoachingDetail(parsed), {
      targetPaceSec: Number(process.env.COACH_TARGET_PACE_SEC || 370),
      targetRpe: process.env.COACH_TARGET_RPE || '6~7'
    });

    const shouldPost = shouldSendToDiscord(body);
    let postedToDiscord = false;
    if (shouldPost) {
      await postDiscord(buildAppleHealthDiscordMessage(summary, coaching));
      postedToDiscord = Boolean(process.env.DISCORD_WEBHOOK_URL);
    }

    const stored = await upsertStoredRun(normalizeAppleHealthRunForStore(parsed, summary, coaching));

    return res.status(200).json({
      ok: true,
      id: parsed.externalRunId,
      source: 'apple-health',
      contractVersion: '2026-05-25',
      postedToDiscord,
      summary,
      coaching,
      stored: {
        inserted: stored.inserted,
        count: stored.count
      },
      accepted: {
        splitCount: parsed.splits.length,
        routePointCount: parsed.routePoints.length
      }
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
