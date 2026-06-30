function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function toNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function latestWeek(summaries) {
  return [...summaries].sort((a, b) => String(b.week_start || '').localeCompare(String(a.week_start || '')))[0] || null;
}

function previousWeeks(summaries, latest) {
  return summaries.filter((item) => item !== latest && item.week_start !== latest?.week_start);
}

function groupKey(row, opts = {}) {
  return [
    row.subject_person_id || opts.subjectPersonId || '',
    row.organization_id || opts.organizationId || '',
    row.org_client_profile_id || opts.orgClientProfileId || '',
    row.source || ''
  ].join('|');
}

function average(values) {
  const clean = values.map(Number).filter(Number.isFinite);
  if (!clean.length) return null;
  return clean.reduce((sum, value) => sum + value, 0) / clean.length;
}

function trendDirection(delta, threshold) {
  if (!Number.isFinite(delta)) return undefined;
  if (delta >= threshold) return 'up';
  if (delta <= -threshold) return 'down';
  return 'flat';
}

function dataQualityForWeeklyState(rows, latest, priorKmAverage) {
  const weekCount = rows.length;
  const totalKm = toNumber(latest.total_km);
  const movingSec = toNumber(latest.moving_time_sec);
  const runCount = toNumber(latest.run_count);
  const reasons = [];

  if (weekCount < 2) reasons.push('missing_prior_baseline');
  if (weekCount < 4) reasons.push('short_history');
  if (!Number.isFinite(priorKmAverage) || priorKmAverage <= 0) reasons.push('limited_load_comparison');
  if (runCount <= 0) reasons.push('no_runs_this_week');
  if (totalKm <= 0) reasons.push('missing_weekly_distance');
  if (movingSec <= 0) reasons.push('missing_moving_time');

  const level = reasons.length === 0
    ? 'supported'
    : (reasons.length <= 2 && weekCount >= 2 ? 'partial' : 'limited');

  return {
    level,
    weekCount,
    hasPriorBaseline: Number.isFinite(priorKmAverage) && priorKmAverage > 0,
    insufficientDataReasons: reasons
  };
}

function hasPositiveNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0;
}

function metricCoverageForWeeklyState(latest) {
  return {
    pace: hasPositiveNumber(latest.average_pace_sec_per_km),
    heartRate: hasPositiveNumber(latest.average_heartrate),
    cadence: hasPositiveNumber(latest.average_cadence)
  };
}

function missingMetricReasons(coverage) {
  const reasons = [];
  if (!coverage.pace) reasons.push('missing_average_pace');
  if (!coverage.heartRate) reasons.push('missing_average_heartrate');
  if (!coverage.cadence) reasons.push('missing_average_cadence');
  return reasons;
}

function confidenceForWeeklyState(rows, dataQuality) {
  const base = clamp(0.45 + Math.min(rows.length, 4) * 0.1, 0.45, 0.85);
  const penalty = {
    supported: 0,
    partial: 0.08,
    limited: 0.16
  }[dataQuality.level] || 0;

  return Number(clamp(base - penalty, 0.35, 0.85).toFixed(3));
}

function buildWeeklyActivityStateSnapshotsForGroup(summaries, opts = {}) {
  const rows = Array.isArray(summaries) ? summaries.filter(Boolean) : [];
  const latest = latestWeek(rows);
  if (!latest) return [];

  const subjectPersonId = latest.subject_person_id || opts.subjectPersonId;
  if (!subjectPersonId) return [];

  const prior = previousWeeks(rows, latest);
  const totalKm = toNumber(latest.total_km);
  const movingMinutes = toNumber(latest.moving_time_sec) / 60;
  const runCount = toNumber(latest.run_count);
  const priorKmAverage = average(prior.map((item) => item.total_km));
  const priorMovingMinutesAverage = average(prior.map((item) => toNumber(item.moving_time_sec) / 60));
  const priorRunCountAverage = average(prior.map((item) => item.run_count));
  const loadRatio = priorKmAverage && priorKmAverage > 0 ? totalKm / priorKmAverage : null;
  const loadIncrease = loadRatio === null ? 0 : Math.max(0, loadRatio - 1);
  const dataQuality = dataQualityForWeeklyState(rows, latest, priorKmAverage);
  const totalKmDelta = priorKmAverage === null ? null : totalKm - priorKmAverage;
  const movingMinutesDelta = priorMovingMinutesAverage === null ? null : movingMinutes - priorMovingMinutesAverage;
  const runCountDelta = priorRunCountAverage === null ? null : runCount - priorRunCountAverage;
  const volumeTrend = totalKmDelta === null ? undefined : trendDirection(totalKmDelta, 2);
  const adherenceTrend = runCountDelta === null ? undefined : trendDirection(runCountDelta, 0.75);
  const metricCoverage = metricCoverageForWeeklyState(latest);
  const metricGaps = missingMetricReasons(metricCoverage);

  const base = {
    subjectPersonId,
    organizationId: latest.organization_id || opts.organizationId,
    orgClientProfileId: latest.org_client_profile_id || opts.orgClientProfileId,
    calculatedAt: opts.calculatedAt || new Date().toISOString(),
    windowStart: latest.week_start,
    windowEnd: latest.last_run_at,
    source: 'run_log_weekly_summaries',
    providerSource: latest.source
  };

  const trainingLoad = clamp((totalKm / 50) * 0.7 + (movingMinutes / 300) * 0.3, 0, 1);
  const adherence = clamp(runCount / toNumber(opts.targetRunsPerWeek || 3, 3), 0, 1);
  const fatigue = clamp(trainingLoad * 0.55 + loadIncrease * 0.35 + Math.max(0, runCount - 4) * 0.05, 0, 1);
  const confidence = confidenceForWeeklyState(rows, dataQuality);
  const qualityMetadata = {
    dataQuality: dataQuality.level,
    dataQualityWeekCount: dataQuality.weekCount,
    hasPriorBaseline: dataQuality.hasPriorBaseline,
    sourceActivityCount: runCount,
    firstRunAt: latest.first_run_at,
    latestRunAt: latest.last_run_at,
    metricCoverage,
    missingMetricReasons: metricGaps.length ? metricGaps : undefined,
    insufficientDataReasons: dataQuality.insufficientDataReasons.length ? dataQuality.insufficientDataReasons : undefined
  };
  const trendMetadata = {
    totalKmDelta: totalKmDelta === null ? undefined : Number(totalKmDelta.toFixed(2)),
    movingMinutesDelta: movingMinutesDelta === null ? undefined : Math.round(movingMinutesDelta),
    runCountDelta: runCountDelta === null ? undefined : Number(runCountDelta.toFixed(2)),
    volumeTrend,
    adherenceTrend
  };

  return [
    {
      ...base,
      stateType: 'training_load',
      value: Number(trainingLoad.toFixed(3)),
      confidence,
      metadata: compactObject({
        totalKm,
        movingMinutes: Math.round(movingMinutes),
        runCount,
        priorKmAverage: priorKmAverage === null ? undefined : Number(priorKmAverage.toFixed(2)),
        ...trendMetadata,
        ...qualityMetadata,
        interpretation: 'weekly activity volume normalized for MVP display'
      })
    },
    {
      ...base,
      stateType: 'adherence',
      value: Number(adherence.toFixed(3)),
      confidence,
      metadata: compactObject({
        runCount,
        targetRunsPerWeek: toNumber(opts.targetRunsPerWeek || 3, 3),
        runCountDelta: trendMetadata.runCountDelta,
        adherenceTrend,
        ...qualityMetadata,
        interpretation: 'weekly run frequency against configured target'
      })
    },
    {
      ...base,
      stateType: 'fatigue',
      value: Number(fatigue.toFixed(3)),
      confidence: Number(Math.max(0.35, confidence - 0.1).toFixed(3)),
      metadata: compactObject({
        totalKm,
        priorKmAverage: priorKmAverage === null ? undefined : Number(priorKmAverage.toFixed(2)),
        loadRatio: loadRatio === null ? undefined : Number(loadRatio.toFixed(2)),
        totalKmDelta: trendMetadata.totalKmDelta,
        volumeTrend,
        ...qualityMetadata,
        interpretation: 'heuristic fatigue signal from recent volume and week-over-week load increase'
      })
    }
  ];
}

export function buildWeeklyActivityStateSnapshots(summaries, opts = {}) {
  const rows = Array.isArray(summaries) ? summaries.filter(Boolean) : [];
  const grouped = new Map();

  for (const row of rows) {
    const key = groupKey(row, opts);
    const group = grouped.get(key) || [];
    group.push(row);
    grouped.set(key, group);
  }

  return [...grouped.values()].flatMap((group) => buildWeeklyActivityStateSnapshotsForGroup(group, opts));
}

export function snapshotRowToApi(row, inputs = []) {
  return compactObject({
    id: row.id,
    subjectPersonId: row.subject_person_id,
    organizationId: row.organization_id,
    orgClientProfileId: row.org_client_profile_id,
    stateType: row.state_type,
    value: row.value,
    confidence: row.confidence,
    calculatedAt: row.calculated_at,
    windowStart: row.window_start,
    windowEnd: row.window_end,
    source: row.source,
    providerSource: row.provider_source,
    metadata: row.metadata,
    inputs: inputs.length
      ? inputs.map((input) =>
          compactObject({
            runLogRunId: input.run_log_run_id,
            pghdActivityEventId: input.pghd_activity_event_id,
            weight: input.weight,
            activity: input.activity
          })
        )
      : undefined
  });
}
