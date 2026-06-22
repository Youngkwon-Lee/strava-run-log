import { createHash } from 'node:crypto';

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function decodeXml(value) {
  return String(value || '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}

function firstText(xml, tagName) {
  const match = String(xml || '').match(new RegExp(`<(?:[\\w-]+:)?${tagName}\\b[^>]*>([\\s\\S]*?)<\\/(?:[\\w-]+:)?${tagName}>`, 'i'));
  return match ? decodeXml(match[1].trim()) : '';
}

function numberFromText(xml, tagName) {
  const value = Number(firstText(xml, tagName));
  return Number.isFinite(value) ? value : undefined;
}

function attr(attrs, name) {
  const match = String(attrs || '').match(new RegExp(`${name}=["']([^"']+)["']`, 'i'));
  return match ? decodeXml(match[1]) : '';
}

function toIso(value) {
  const time = Date.parse(value);
  return Number.isFinite(time) ? new Date(time).toISOString() : undefined;
}

function formatDuration(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return undefined;
  const rounded = Math.round(seconds);
  const h = Math.floor(rounded / 3600);
  const m = Math.floor((rounded % 3600) / 60);
  const s = rounded % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    : `${m}:${String(s).padStart(2, '0')}`;
}

function formatPace(secondsPerKm) {
  if (!Number.isFinite(secondsPerKm) || secondsPerKm <= 0) return undefined;
  const rounded = Math.round(secondsPerKm);
  return `${Math.floor(rounded / 60)}:${String(rounded % 60).padStart(2, '0')} /km`;
}

function haversineMeters(a, b) {
  if (!Number.isFinite(a.lat) || !Number.isFinite(a.lon) || !Number.isFinite(b.lat) || !Number.isFinite(b.lon)) {
    return 0;
  }
  const radius = 6371000;
  const toRad = (value) => (value * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * radius * Math.asin(Math.sqrt(h));
}

function average(values) {
  const nums = values.map(Number).filter(Number.isFinite);
  if (!nums.length) return undefined;
  return nums.reduce((sum, value) => sum + value, 0) / nums.length;
}

function detectFormat({ filename = '', format = '', content = '' }) {
  const explicit = String(format || '').trim().toLowerCase().replace(/^\./, '');
  if (['gpx', 'tcx', 'fit'].includes(explicit)) return explicit;

  const extension = String(filename || '').split('.').pop()?.toLowerCase();
  if (['gpx', 'tcx', 'fit'].includes(extension)) return extension;

  const text = String(content || '').trim().slice(0, 300).toLowerCase();
  if (text.includes('<gpx')) return 'gpx';
  if (text.includes('<trainingcenterdatabase')) return 'tcx';
  return '';
}

function buildRun({ format, filename, content, name, points, distanceMeters }) {
  const first = points[0] || {};
  const last = points[points.length - 1] || {};
  const startDate = first.time;
  const endedAt = last.time;
  const movingTimeSec = startDate && endedAt ? Math.max(0, Math.round((Date.parse(endedAt) - Date.parse(startDate)) / 1000)) : undefined;
  const distance = Number(distanceMeters || 0);
  const distanceKm = distance > 0 ? Number((distance / 1000).toFixed(2)) : undefined;
  const paceSecPerKm = distanceKm && movingTimeSec ? movingTimeSec / distanceKm : undefined;
  const elevations = points.map((point) => point.ele).filter(Number.isFinite);
  const hrValues = points.map((point) => point.hr).filter(Number.isFinite);
  const hash = createHash('sha256').update(`${format}:${filename}:${content}`).digest('hex').slice(0, 20);

  return compactObject({
    id: `file-${hash}`,
    externalId: `file-${hash}`,
    source: 'file-import',
    provider: 'file-import',
    name: name || `${format.toUpperCase()} Run`,
    startDate,
    startedAt: startDate,
    endedAt,
    distanceMeters: distance ? Math.round(distance) : undefined,
    distanceKm,
    movingTimeSec,
    movingTime: formatDuration(movingTimeSec),
    elapsedTimeSec: movingTimeSec,
    elapsedTime: formatDuration(movingTimeSec),
    paceSecPerKm: paceSecPerKm ? Math.round(paceSecPerKm) : undefined,
    pace: formatPace(paceSecPerKm),
    averageHeartrate: average(hrValues) ? Math.round(average(hrValues)) : undefined,
    minElevationMeters: elevations.length ? Math.min(...elevations) : undefined,
    maxElevationMeters: elevations.length ? Math.max(...elevations) : undefined,
    deviceName: filename || `${format.toUpperCase()} file`,
    sourceApp: 'file-upload',
    routePointCount: points.length,
    fileFormat: format,
    filename
  });
}

export function parseGpxRun(content, opts = {}) {
  const xml = String(content || '');
  const points = [...xml.matchAll(/<trkpt\b([^>]*)>([\s\S]*?)<\/trkpt>/gi)]
    .map((match) => {
      const lat = Number(attr(match[1], 'lat'));
      const lon = Number(attr(match[1], 'lon'));
      const time = toIso(firstText(match[2], 'time'));
      return compactObject({
        lat,
        lon,
        ele: numberFromText(match[2], 'ele'),
        time,
        hr: numberFromText(match[2], 'hr')
      });
    })
    .filter((point) => Number.isFinite(point.lat) && Number.isFinite(point.lon));

  if (points.length < 2) throw new Error('GPX track must include at least 2 track points');

  const distanceMeters = points.reduce((sum, point, index) => {
    if (index === 0) return 0;
    return sum + haversineMeters(points[index - 1], point);
  }, 0);

  return buildRun({
    format: 'gpx',
    filename: opts.filename,
    content: xml,
    name: firstText(xml, 'name'),
    points,
    distanceMeters
  });
}

export function parseTcxRun(content, opts = {}) {
  const xml = String(content || '');
  const points = [...xml.matchAll(/<Trackpoint\b[^>]*>([\s\S]*?)<\/Trackpoint>/gi)]
    .map((match) =>
      compactObject({
        time: toIso(firstText(match[1], 'Time')),
        distanceMeters: numberFromText(match[1], 'DistanceMeters'),
        ele: numberFromText(match[1], 'AltitudeMeters'),
        hr: numberFromText(match[1], 'Value')
      })
    )
    .filter((point) => point.time);

  if (points.length < 2) throw new Error('TCX activity must include at least 2 track points');

  const distances = points.map((point) => point.distanceMeters).filter(Number.isFinite);
  const distanceMeters = distances.length ? Math.max(...distances) : 0;

  return buildRun({
    format: 'tcx',
    filename: opts.filename,
    content: xml,
    name: firstText(xml, 'Id') || firstText(xml, 'Notes'),
    points,
    distanceMeters
  });
}

export function parseRunFile(input = {}) {
  const content = input.contentBase64
    ? Buffer.from(String(input.contentBase64), 'base64').toString('utf8')
    : String(input.content || '');
  const format = detectFormat({ ...input, content });

  if (!format) throw new Error('unsupported file format');
  if (format === 'fit') {
    const error = new Error('FIT import requires a binary FIT parser and is not enabled yet');
    error.code = 'UNSUPPORTED_FIT';
    throw error;
  }
  if (!content.trim()) throw new Error('file content is required');

  if (format === 'gpx') return parseGpxRun(content, { filename: input.filename });
  if (format === 'tcx') return parseTcxRun(content, { filename: input.filename });
  throw new Error('unsupported file format');
}
