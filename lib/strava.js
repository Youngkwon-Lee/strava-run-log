const STRAVA_API_BASE = 'https://www.strava.com/api/v3';
const STRAVA_OAUTH_URL = 'https://www.strava.com/oauth/token';
const RUN_SPORT_TYPES = new Set(['Run', 'TrailRun', 'VirtualRun']);
const DEFAULT_STREAM_KEYS = [
  'latlng',
  'time',
  'distance',
  'altitude',
  'velocity_smooth',
  'heartrate',
  'cadence',
  'temp',
  'moving',
  'grade_smooth'
];

function clampInteger(value, { min, max, fallback }) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function toIsoOrUndefined(value) {
  if (!value) return undefined;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

function secToClock(totalSec) {
  const sec = Math.max(0, Math.round(Number(totalSec || 0)));
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    : `${m}:${String(s).padStart(2, '0')}`;
}

function paceSecFor(distanceMeters, movingSec) {
  const distanceKm = Number(distanceMeters || 0) / 1000;
  if (!distanceKm) return null;
  return Number(movingSec || 0) / distanceKm;
}

function secToPace(secPerKm) {
  if (!Number.isFinite(secPerKm) || secPerKm <= 0) return null;
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60);
  return `${m}:${String(s).padStart(2, '0')}/km`;
}

function normalizeSplit(split) {
  const paceSec = paceSecFor(split.distance, split.moving_time || split.elapsed_time);
  return compactObject({
    split: split.split,
    distanceMeters: split.distance,
    movingTimeSec: split.moving_time,
    elapsedTimeSec: split.elapsed_time,
    paceSecPerKm: paceSec ? Math.round(paceSec) : undefined,
    pace: secToPace(paceSec),
    elevationDifferenceMeters: split.elevation_difference,
    averageSpeedMetersPerSec: split.average_speed,
    averageHeartrate: split.average_heartrate,
    averageGradeAdjustedSpeed: split.average_grade_adjusted_speed
  });
}

function normalizeLap(lap) {
  const paceSec = paceSecFor(lap.distance, lap.moving_time || lap.elapsed_time);
  return compactObject({
    id: lap.id,
    name: lap.name,
    split: lap.split,
    lapIndex: lap.lap_index,
    distanceMeters: lap.distance,
    movingTimeSec: lap.moving_time,
    elapsedTimeSec: lap.elapsed_time,
    paceSecPerKm: paceSec ? Math.round(paceSec) : undefined,
    pace: secToPace(paceSec),
    totalElevationGainMeters: lap.total_elevation_gain,
    averageSpeedMetersPerSec: lap.average_speed,
    maxSpeedMetersPerSec: lap.max_speed,
    averageHeartrate: lap.average_heartrate,
    maxHeartrate: lap.max_heartrate,
    averageCadence: lap.average_cadence
  });
}

function getStreamData(streams, key) {
  if (!streams) return [];
  if (Array.isArray(streams)) {
    return streams.find((stream) => stream?.type === key)?.data || [];
  }
  return streams[key]?.data || [];
}

function minMax(values) {
  if (!Array.isArray(values) || values.length === 0) return {};
  return values.reduce(
    (acc, value) => {
      const n = Number(value);
      if (!Number.isFinite(n)) return acc;
      return {
        min: Math.min(acc.min, n),
        max: Math.max(acc.max, n)
      };
    },
    { min: Infinity, max: -Infinity }
  );
}

function computeBounds(latlng) {
  if (!Array.isArray(latlng) || latlng.length === 0) return undefined;
  const bounds = latlng.reduce(
    (acc, point) => {
      if (!Array.isArray(point) || point.length < 2) return acc;
      const [lat, lng] = point.map(Number);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return acc;
      return {
        minLat: Math.min(acc.minLat, lat),
        maxLat: Math.max(acc.maxLat, lat),
        minLng: Math.min(acc.minLng, lng),
        maxLng: Math.max(acc.maxLng, lng)
      };
    },
    { minLat: Infinity, maxLat: -Infinity, minLng: Infinity, maxLng: -Infinity }
  );
  return Number.isFinite(bounds.minLat) ? bounds : undefined;
}

function normalizeStreams(streams) {
  if (!streams) return undefined;
  if (Array.isArray(streams)) {
    return Object.fromEntries(streams.map((stream) => [stream.type, stream]));
  }
  return streams;
}

export async function refreshTokenIfNeeded() {
  const now = Math.floor(Date.now() / 1000);
  const exp = Number(process.env.STRAVA_TOKEN_EXPIRES_AT || 0);
  if (process.env.STRAVA_ACCESS_TOKEN && exp > now + 120) return process.env.STRAVA_ACCESS_TOKEN;

  if (!process.env.STRAVA_CLIENT_ID || !process.env.STRAVA_CLIENT_SECRET || !process.env.STRAVA_REFRESH_TOKEN) {
    throw new Error('missing Strava OAuth env: STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET, STRAVA_REFRESH_TOKEN');
  }

  const body = new URLSearchParams({
    client_id: process.env.STRAVA_CLIENT_ID,
    client_secret: process.env.STRAVA_CLIENT_SECRET,
    grant_type: 'refresh_token',
    refresh_token: process.env.STRAVA_REFRESH_TOKEN
  });

  const r = await fetch(STRAVA_OAUTH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body
  });
  if (!r.ok) throw new Error(`refresh failed: ${r.status}`);
  const j = await r.json();

  process.env.STRAVA_ACCESS_TOKEN = j.access_token;
  process.env.STRAVA_REFRESH_TOKEN = j.refresh_token;
  process.env.STRAVA_TOKEN_EXPIRES_AT = String(j.expires_at);
  return j.access_token;
}

export async function stravaGet(path, token, params = {}) {
  const url = new URL(`${STRAVA_API_BASE}${path.startsWith('/') ? path : `/${path}`}`);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(key, String(value));
    }
  }

  const r = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (!r.ok) {
    const body = await r.text().catch(() => '');
    throw new Error(`strava request failed: ${r.status} ${path}${body ? ` ${body.slice(0, 160)}` : ''}`);
  }
  return r.json();
}

export async function listAthleteActivities(token, opts = {}) {
  const perPage = clampInteger(opts.perPage, { min: 1, max: 200, fallback: 100 });
  const limit = clampInteger(opts.limit, { min: 1, max: 500, fallback: perPage });
  const maxPages = clampInteger(opts.maxPages, { min: 1, max: 10, fallback: Math.ceil(limit / perPage) || 1 });
  const activities = [];

  for (let page = 1; page <= maxPages && activities.length < limit; page += 1) {
    const batch = await stravaGet('/athlete/activities', token, {
      after: opts.after,
      before: opts.before,
      page,
      per_page: perPage
    });
    if (!Array.isArray(batch)) throw new Error('unexpected Strava activities response');
    activities.push(...batch);
    if (batch.length < perPage) break;
  }

  return activities.slice(0, limit);
}

export async function getActivityDetail(activityId, token, opts = {}) {
  return stravaGet(`/activities/${activityId}`, token, {
    include_all_efforts: opts.includeAllEfforts === false ? undefined : true
  });
}

export async function getActivityStreams(activityId, token, keys = DEFAULT_STREAM_KEYS) {
  const response = await stravaGet(`/activities/${activityId}/streams`, token, {
    keys: keys.join(','),
    key_by_type: true
  });
  return normalizeStreams(response);
}

export function isRunActivity(activity) {
  return RUN_SPORT_TYPES.has(activity?.sport_type) || RUN_SPORT_TYPES.has(activity?.type);
}

export function summarizeStreams(streams) {
  const normalized = normalizeStreams(streams);
  if (!normalized) return undefined;

  const latlng = getStreamData(normalized, 'latlng');
  const distance = getStreamData(normalized, 'distance');
  const time = getStreamData(normalized, 'time');
  const altitude = getStreamData(normalized, 'altitude');
  const heartrate = getStreamData(normalized, 'heartrate');
  const cadence = getStreamData(normalized, 'cadence');
  const altitudeRange = minMax(altitude);
  const heartrateRange = minMax(heartrate);
  const cadenceRange = minMax(cadence);

  return compactObject({
    keys: Object.keys(normalized),
    pointCount: Math.max(latlng.length, distance.length, time.length, altitude.length, heartrate.length, cadence.length),
    hasRoute: latlng.length > 0,
    startLatlng: latlng[0],
    endLatlng: latlng[latlng.length - 1],
    bounds: computeBounds(latlng),
    lastDistanceMeters: distance[distance.length - 1],
    durationSec: time[time.length - 1],
    altitudeMinMeters: Number.isFinite(altitudeRange.min) ? altitudeRange.min : undefined,
    altitudeMaxMeters: Number.isFinite(altitudeRange.max) ? altitudeRange.max : undefined,
    heartrateMin: Number.isFinite(heartrateRange.min) ? heartrateRange.min : undefined,
    heartrateMax: Number.isFinite(heartrateRange.max) ? heartrateRange.max : undefined,
    cadenceMin: Number.isFinite(cadenceRange.min) ? cadenceRange.min : undefined,
    cadenceMax: Number.isFinite(cadenceRange.max) ? cadenceRange.max : undefined
  });
}

export function normalizeActivity(activity, opts = {}) {
  const paceSec = paceSecFor(activity.distance, activity.moving_time);
  const streams = normalizeStreams(opts.streams);
  const streamSummary = summarizeStreams(streams);

  return compactObject({
    id: activity.id,
    externalUrl: activity.id ? `https://www.strava.com/activities/${activity.id}` : undefined,
    name: activity.name,
    description: activity.description,
    type: activity.type,
    sportType: activity.sport_type,
    workoutType: activity.workout_type,
    startDate: toIsoOrUndefined(activity.start_date),
    startDateLocal: activity.start_date_local,
    timezone: activity.timezone,
    utcOffsetSec: activity.utc_offset,
    distanceMeters: activity.distance,
    distanceKm: activity.distance !== undefined ? Number((Number(activity.distance || 0) / 1000).toFixed(2)) : undefined,
    movingTimeSec: activity.moving_time,
    movingTime: secToClock(activity.moving_time),
    elapsedTimeSec: activity.elapsed_time,
    elapsedTime: secToClock(activity.elapsed_time),
    paceSecPerKm: paceSec ? Math.round(paceSec) : undefined,
    pace: secToPace(paceSec),
    averageSpeedMetersPerSec: activity.average_speed,
    maxSpeedMetersPerSec: activity.max_speed,
    totalElevationGainMeters: activity.total_elevation_gain,
    elevHighMeters: activity.elev_high,
    elevLowMeters: activity.elev_low,
    averageHeartrate: activity.average_heartrate,
    maxHeartrate: activity.max_heartrate,
    averageCadence: activity.average_cadence,
    calories: activity.calories,
    sufferScore: activity.suffer_score,
    achievementCount: activity.achievement_count,
    kudosCount: activity.kudos_count,
    commentCount: activity.comment_count,
    athleteCount: activity.athlete_count,
    photoCount: activity.photo_count,
    trainer: activity.trainer,
    commute: activity.commute,
    manual: activity.manual,
    private: activity.private,
    visibility: activity.visibility,
    flagged: activity.flagged,
    deviceName: activity.device_name,
    gearId: activity.gear_id,
    startLatlng: activity.start_latlng,
    endLatlng: activity.end_latlng,
    map: activity.map
      ? compactObject({
          id: activity.map.id,
          summaryPolyline: activity.map.summary_polyline,
          polyline: activity.map.polyline
        })
      : undefined,
    splitsMetric: Array.isArray(activity.splits_metric) ? activity.splits_metric.map(normalizeSplit) : undefined,
    laps: Array.isArray(activity.laps) ? activity.laps.map(normalizeLap) : undefined,
    bestEfforts: Array.isArray(activity.best_efforts)
      ? activity.best_efforts.map((effort) =>
          compactObject({
            id: effort.id,
            name: effort.name,
            distanceMeters: effort.distance,
            movingTimeSec: effort.moving_time,
            elapsedTimeSec: effort.elapsed_time,
            startDate: toIsoOrUndefined(effort.start_date),
            startDateLocal: effort.start_date_local,
            prRank: effort.pr_rank,
            achievements: effort.achievements
          })
        )
      : undefined,
    streamSummary,
    streams: opts.includeStreams ? streams : undefined,
    streamError: opts.streamError
  });
}

export function summarizeActivities(activities) {
  const normalized = activities.map((activity) => ('distanceMeters' in activity ? activity : normalizeActivity(activity)));
  const totalMeters = normalized.reduce((sum, activity) => sum + Number(activity.distanceMeters || 0), 0);
  const movingSec = normalized.reduce((sum, activity) => sum + Number(activity.movingTimeSec || 0), 0);
  const elevationMeters = normalized.reduce((sum, activity) => sum + Number(activity.totalElevationGainMeters || 0), 0);
  const hrValues = normalized.map((activity) => Number(activity.averageHeartrate)).filter(Number.isFinite);
  const cadenceValues = normalized.map((activity) => Number(activity.averageCadence)).filter(Number.isFinite);
  const longest = normalized.reduce((best, activity) => {
    if (!best || Number(activity.distanceMeters || 0) > Number(best.distanceMeters || 0)) return activity;
    return best;
  }, null);

  const avgPaceSec = paceSecFor(totalMeters, movingSec);
  return compactObject({
    runCount: normalized.length,
    totalKm: Number((totalMeters / 1000).toFixed(2)),
    movingTimeSec: movingSec,
    movingTime: secToClock(movingSec),
    moderateMinutes: Math.round(movingSec / 60),
    averagePaceSecPerKm: avgPaceSec ? Math.round(avgPaceSec) : undefined,
    averagePace: secToPace(avgPaceSec),
    totalElevationGainMeters: Math.round(elevationMeters),
    averageHeartrate: hrValues.length
      ? Math.round(hrValues.reduce((sum, value) => sum + value, 0) / hrValues.length)
      : undefined,
    averageCadence: cadenceValues.length
      ? Math.round(cadenceValues.reduce((sum, value) => sum + value, 0) / cadenceValues.length)
      : undefined,
    longestRun: longest
      ? compactObject({
          id: longest.id,
          name: longest.name,
          distanceKm: longest.distanceKm,
          movingTime: longest.movingTime,
          pace: longest.pace,
          startDateLocal: longest.startDateLocal
        })
      : undefined
  });
}

export function summarizeActivity(d) {
  const km = ((d.distance || 0) / 1000).toFixed(2);
  const sec = d.moving_time || 0;
  const mm = Math.floor(sec / 60);
  const ss = sec % 60;
  const paceSec = d.distance ? sec / (d.distance / 1000) : 0;
  const pm = Math.floor(paceSec / 60);
  const ps = Math.round(paceSec % 60);
  return {
    title: d.name || 'Run',
    km,
    moving: `${mm}:${String(ss).padStart(2, '0')}`,
    pace: paceSec ? `${pm}:${String(ps).padStart(2, '0')}/km` : '-',
    paceSec,
    elev: d.total_elevation_gain ?? 0
  };
}
