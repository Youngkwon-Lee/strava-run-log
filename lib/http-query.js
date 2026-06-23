export function parseBoundedLimit(value, { defaultValue = 30, min = 1, max = 100 } = {}) {
  const normalized = value === undefined || value === null ? '' : String(value).trim();
  const parsed = normalized ? Number(normalized) : Number.NaN;
  const configuredMin = Number(min);
  const configuredMax = Number(max);
  const lower = Number.isFinite(configuredMin) ? configuredMin : 1;
  const rawUpper = Number.isFinite(configuredMax) ? configuredMax : 100;
  const upper = Math.max(lower, rawUpper);
  const configuredFallback = Number(defaultValue);
  const fallback = Number.isFinite(configuredFallback) ? configuredFallback : lower;
  const number = Number.isFinite(parsed) ? parsed : fallback;
  const bounded = Math.min(upper, Math.max(lower, number));
  return Math.trunc(bounded);
}
