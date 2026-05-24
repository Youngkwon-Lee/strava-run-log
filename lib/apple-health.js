import { createHmac, timingSafeEqual } from 'node:crypto';

function getHeader(req, name) {
  const headers = req?.headers || {};
  const target = String(name).toLowerCase();
  const key = Object.keys(headers).find((headerName) => String(headerName).toLowerCase() === target);
  return key ? headers[key] : undefined;
}

function parseFiniteNumber(value, { min = -Infinity, max = Infinity, required = false } = {}) {
  if (value === undefined || value === null || value === '') {
    return required ? { error: 'required number missing' } : { value: null };
  }

  const number = Number(value);
  if (!Number.isFinite(number)) return { error: 'must be a finite number' };
  if (number < min || number > max) return { error: `must be between ${min} and ${max}` };
  return { value: number };
}

function parseText(value, field, { required = false, maxLength = 200 } = {}) {
  if (value === undefined || value === null || value === '') {
    return required ? { error: `${field} is required` } : { value: null };
  }

  const text = String(value).trim();
  if (!text) return required ? { error: `${field} is required` } : { value: null };
  if (text.length > maxLength) return { error: `${field} must be ${maxLength} characters or less` };
  return { value: text };
}

function parseIsoDate(value, field, { required = false } = {}) {
  if (value === undefined || value === null || value === '') {
    return required ? { error: `${field} is required` } : { value: null };
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return { error: `${field} must be a valid ISO date` };
  return { value: date.toISOString() };
}

function formatPace(secondsPerKm) {
  if (!Number.isFinite(secondsPerKm) || secondsPerKm <= 0) return null;
  const minutes = Math.floor(secondsPerKm / 60);
  const seconds = Math.round(secondsPerKm % 60);
  return `${minutes}:${String(seconds).padStart(2, '0')}/km`;
}

function formatDuration(totalSec) {
  const sec = Math.max(0, Math.round(Number(totalSec || 0)));
  const hours = Math.floor(sec / 3600);
  const minutes = Math.floor((sec % 3600) / 60);
  const seconds = sec % 60;
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
    : `${minutes}:${String(seconds).padStart(2, '0')}`;
}

function digestHex(secret, bodyText) {
  return createHmac('sha256', secret).update(bodyText).digest('hex');
}

function safeHexEqual(left, right) {
  const a = Buffer.from(String(left || ''), 'utf8');
  const b = Buffer.from(String(right || ''), 'utf8');
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

function parseSplits(splits, errors) {
  if (splits === undefined || splits === null) return [];
  if (!Array.isArray(splits)) {
    errors.push('splits must be an array');
    return [];
  }

  return splits
    .map((split, index) => {
      const km = parseFiniteNumber(split?.km, { min: 0.1, max: 500, required: true });
      const movingTimeSec = parseFiniteNumber(split?.moving_time_s, { min: 1, max: 86400, required: true });
      const avgHr = parseFiniteNumber(split?.avg_hr, { min: 0, max: 240 });
      const maxHr = parseFiniteNumber(split?.max_hr, { min: 0, max: 240 });

      if (km.error) errors.push(`splits[${index}].km ${km.error}`);
      if (movingTimeSec.error) errors.push(`splits[${index}].moving_time_s ${movingTimeSec.error}`);
      if (avgHr.error) errors.push(`splits[${index}].avg_hr ${avgHr.error}`);
      if (maxHr.error) errors.push(`splits[${index}].max_hr ${maxHr.error}`);

      if (km.error || movingTimeSec.error || avgHr.error || maxHr.error) return null;
      return {
        km: km.value,
        movingTimeSec: Math.round(movingTimeSec.value),
        avgHr: avgHr.value,
        maxHr: maxHr.value
      };
    })
    .filter(Boolean);
}

function parseRoutePoints(routePoints, errors) {
  if (routePoints === undefined || routePoints === null) return [];
  if (!Array.isArray(routePoints)) {
    errors.push('route_points must be an array');
    return [];
  }

  return routePoints
    .map((point, index) => {
      const lat = parseFiniteNumber(point?.lat, { min: -90, max: 90, required: true });
      const lng = parseFiniteNumber(point?.lng, { min: -180, max: 180, required: true });
      const altitudeM = parseFiniteNumber(point?.altitude_m, { min: -1000, max: 12000 });
      const distanceM = parseFiniteNumber(point?.distance_m, { min: 0, max: 1000000 });
      const hr = parseFiniteNumber(point?.hr, { min: 0, max: 240 });
      const recordedAt = parseIsoDate(point?.recorded_at, `route_points[${index}].recorded_at`);

      if (lat.error) errors.push(`route_points[${index}].lat ${lat.error}`);
      if (lng.error) errors.push(`route_points[${index}].lng ${lng.error}`);
      if (altitudeM.error) errors.push(`route_points[${index}].altitude_m ${altitudeM.error}`);
      if (distanceM.error) errors.push(`route_points[${index}].distance_m ${distanceM.error}`);
      if (hr.error) errors.push(`route_points[${index}].hr ${hr.error}`);
      if (recordedAt.error) errors.push(recordedAt.error);

      if (lat.error || lng.error || altitudeM.error || distanceM.error || hr.error || recordedAt.error) return null;
      return {
        lat: lat.value,
        lng: lng.value,
        altitudeM: altitudeM.value,
        distanceM: distanceM.value,
        hr: hr.value,
        recordedAt: recordedAt.value
      };
    })
    .filter(Boolean);
}

export function validateAppleHealthPayload(body) {
  const errors = [];
  const externalRunId = parseText(body?.external_run_id, 'external_run_id', { required: true, maxLength: 160 });
  const userId = parseText(body?.user_id, 'user_id', { required: false, maxLength: 80 });
  const startedAt = parseIsoDate(body?.started_at, 'started_at', { required: true });
  const endedAt = parseIsoDate(body?.ended_at, 'ended_at', { required: true });
  const distanceM = parseFiniteNumber(body?.distance_m, { min: 0.05, max: 1000000, required: true });
  const movingTimeS = parseFiniteNumber(body?.moving_time_s, { min: 1, max: 86400, required: true });
  const elapsedTimeS = parseFiniteNumber(body?.elapsed_time_s, { min: 1, max: 86400 });
  const elevationGainM = parseFiniteNumber(body?.elevation_gain_m, { min: -500, max: 30000 });
  const avgHr = parseFiniteNumber(body?.avg_hr, { min: 0, max: 240 });
  const maxHr = parseFiniteNumber(body?.max_hr, { min: 0, max: 240 });
  const cadenceAvg = parseFiniteNumber(body?.cadence_avg, { min: 0, max: 260 });
  const calories = parseFiniteNumber(body?.calories, { min: 0, max: 50000 });
  const deviceSource = parseText(body?.device_source, 'device_source', { maxLength: 120 });
  const sourceApp = parseText(body?.source_app, 'source_app', { maxLength: 120 });

  for (const result of [
    externalRunId,
    userId,
    startedAt,
    endedAt,
    distanceM,
    movingTimeS,
    elapsedTimeS,
    elevationGainM,
    avgHr,
    maxHr,
    cadenceAvg,
    calories,
    deviceSource,
    sourceApp
  ]) {
    if (result.error) errors.push(result.error);
  }

  const splits = parseSplits(body?.splits, errors);
  const routePoints = parseRoutePoints(body?.route_points, errors);

  if (!startedAt.error && !endedAt.error && startedAt.value >= endedAt.value) {
    errors.push('ended_at must be after started_at');
  }

  if (!movingTimeS.error && !elapsedTimeS.error && elapsedTimeS.value !== null && elapsedTimeS.value < movingTimeS.value) {
    errors.push('elapsed_time_s must be greater than or equal to moving_time_s');
  }

  return errors.length
    ? { errors }
    : {
        externalRunId: externalRunId.value,
        userId: userId.value || 'default',
        startedAt: startedAt.value,
        endedAt: endedAt.value,
        distanceM: distanceM.value,
        movingTimeS: Math.round(movingTimeS.value),
        elapsedTimeS: elapsedTimeS.value === null ? Math.round(movingTimeS.value) : Math.round(elapsedTimeS.value),
        elevationGainM: elevationGainM.value,
        avgHr: avgHr.value,
        maxHr: maxHr.value,
        cadenceAvg: cadenceAvg.value,
        calories: calories.value,
        deviceSource: deviceSource.value || 'Apple Health',
        sourceApp: sourceApp.value || 'Apple Health',
        splits,
        routePoints
      };
}

export function verifyAppleHealthRequest(req, body) {
  const expectedToken = process.env.APPLE_HEALTH_INGEST_TOKEN || process.env.LIVE_METRICS_TOKEN;
  if (expectedToken) {
    const auth = String(getHeader(req, 'authorization') || '');
    const bearer = auth.startsWith('Bearer ') ? auth.slice('Bearer '.length).trim() : '';
    const xApiKey = String(getHeader(req, 'x-api-key') || '').trim();
    if (bearer !== expectedToken && xApiKey !== expectedToken) {
      return { error: 'unauthorized', statusCode: 401 };
    }
  }

  const signingSecret = process.env.APPLE_HEALTH_SIGNING_SECRET;
  if (signingSecret) {
    const signature = String(getHeader(req, 'x-signature') || getHeader(req, 'x-apple-health-signature') || '').trim();
    if (!signature) return { error: 'missing signature', statusCode: 401 };

    const bodyText = typeof req?.rawBody === 'string' ? req.rawBody : JSON.stringify(body ?? {});
    const expectedSignature = digestHex(signingSecret, bodyText);
    if (!safeHexEqual(signature, expectedSignature)) {
      return { error: 'invalid signature', statusCode: 401 };
    }
  }

  return { ok: true };
}

export function summarizeAppleHealthRun(run) {
  const distanceKm = Number((run.distanceM / 1000).toFixed(2));
  const paceSec = run.distanceM > 0 ? run.movingTimeS / (run.distanceM / 1000) : null;
  return {
    id: run.externalRunId,
    source: 'apple-health',
    userId: run.userId,
    startedAt: run.startedAt,
    endedAt: run.endedAt,
    distanceKm,
    distanceM: run.distanceM,
    movingTime: formatDuration(run.movingTimeS),
    movingTimeS: run.movingTimeS,
    elapsedTime: formatDuration(run.elapsedTimeS),
    elapsedTimeS: run.elapsedTimeS,
    pace: formatPace(paceSec),
    paceSecPerKm: paceSec ? Math.round(paceSec) : null,
    elevationGainM: run.elevationGainM,
    avgHr: run.avgHr,
    maxHr: run.maxHr,
    cadenceAvg: run.cadenceAvg,
    calories: run.calories,
    deviceSource: run.deviceSource,
    sourceApp: run.sourceApp,
    splitCount: run.splits.length,
    routePointCount: run.routePoints.length
  };
}

export function toCoachingDetail(run) {
  return {
    name: `${run.sourceApp || 'Apple Health'} Run`,
    distance: run.distanceM,
    moving_time: run.movingTimeS,
    elapsed_time: run.elapsedTimeS,
    total_elevation_gain: run.elevationGainM ?? 0,
    average_heartrate: run.avgHr ?? undefined,
    max_heartrate: run.maxHr ?? undefined,
    average_cadence: run.cadenceAvg ?? undefined,
    splits_metric: run.splits.map((split) => ({
      split: split.km,
      distance: split.km * 1000,
      moving_time: split.movingTimeSec,
      average_heartrate: split.avgHr ?? undefined,
      max_heartrate: split.maxHr ?? undefined
    }))
  };
}

export function buildAppleHealthDiscordMessage(summary, coaching) {
  const lines = [
    '🍎 Apple Health 러닝 수집',
    `- ${summary.distanceKm}km · ${summary.movingTime} · ${summary.pace || '-'} · 상승 ${Math.round(summary.elevationGainM ?? 0)}m`,
    `- source ${summary.sourceApp}${summary.deviceSource ? ` · device ${summary.deviceSource}` : ''}`,
    summary.avgHr ? `- 평균 HR ${Math.round(summary.avgHr)}${summary.maxHr ? ` · 최대 HR ${Math.round(summary.maxHr)}` : ''}` : '',
    summary.cadenceAvg ? `- 케이던스 ${Math.round(summary.cadenceAvg)}` : '',
    '',
    coaching
  ];
  return lines.filter(Boolean).join('\n');
}
