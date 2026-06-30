function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function toNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function stateTime(snapshot) {
  if (!snapshot) return Number.NaN;
  return Date.parse(snapshot.calculatedAt || snapshot.calculated_at || snapshot.windowEnd || snapshot.window_end || snapshot.windowStart || snapshot.window_start || '');
}

function stateType(snapshot) {
  return snapshot.stateType || snapshot.state_type || '';
}

function providerSource(snapshot) {
  return snapshot.providerSource || snapshot.provider_source || snapshot.source || 'all';
}

function metadata(snapshot) {
  return snapshot.metadata && typeof snapshot.metadata === 'object' ? snapshot.metadata : {};
}

function latestSnapshotsByType(snapshots) {
  const byType = new Map();
  for (const snapshot of snapshots || []) {
    const key = stateType(snapshot);
    if (!key) continue;
    const current = byType.get(key);
    const currentTime = stateTime(current);
    const snapshotTime = stateTime(snapshot);
    if (!current || (Number.isFinite(snapshotTime) && (!Number.isFinite(currentTime) || snapshotTime > currentTime))) {
      byType.set(key, snapshot);
    }
  }
  return byType;
}

function confidenceFromSnapshots(snapshots) {
  const values = (snapshots || []).map((snapshot) => toNumber(snapshot.confidence)).filter((value) => value !== null);
  if (!values.length) return undefined;
  const average = values.reduce((sum, value) => sum + value, 0) / values.length;
  return Number(average.toFixed(3));
}

function sourceSnapshotRefs(snapshots) {
  return (snapshots || []).filter(Boolean).map((snapshot) =>
    compactObject({
      id: snapshot.id,
      stateType: stateType(snapshot),
      value: snapshot.value,
      confidence: snapshot.confidence,
      providerSource: providerSource(snapshot),
      windowStart: snapshot.windowStart || snapshot.window_start,
      windowEnd: snapshot.windowEnd || snapshot.window_end,
      dataQuality: metadata(snapshot).dataQuality,
      dataQualityWeekCount: metadata(snapshot).dataQualityWeekCount,
      hasPriorBaseline: metadata(snapshot).hasPriorBaseline,
      insufficientDataReasons: metadata(snapshot).insufficientDataReasons,
      sourceActivityCount: metadata(snapshot).sourceActivityCount,
      latestRunAt: metadata(snapshot).latestRunAt,
      metricCoverage: metadata(snapshot).metricCoverage,
      missingMetricReasons: metadata(snapshot).missingMetricReasons,
      volumeTrend: metadata(snapshot).volumeTrend,
      adherenceTrend: metadata(snapshot).adherenceTrend,
      inputs: Array.isArray(snapshot.inputs) ? snapshot.inputs.slice(0, 10) : undefined
    })
  );
}

function sourceActivityRefs(snapshots) {
  const byKey = new Map();
  for (const snapshot of snapshots || []) {
    for (const input of Array.isArray(snapshot?.inputs) ? snapshot.inputs : []) {
      const activity = input.activity && typeof input.activity === 'object' ? input.activity : {};
      const key = input.pghdActivityEventId || activity.pghdActivityEventId || input.runLogRunId || activity.id;
      if (!key || byKey.has(key)) continue;
      byKey.set(key, compactObject({
        runLogRunId: input.runLogRunId || activity.id,
        pghdActivityEventId: input.pghdActivityEventId || activity.pghdActivityEventId,
        source: activity.source,
        externalId: activity.externalId,
        name: activity.name,
        startedAt: activity.startedAt,
        distanceKm: activity.distanceKm,
        movingTimeSec: activity.movingTimeSec,
        averageHeartrate: activity.averageHeartrate,
        weight: input.weight
      }));
    }
  }
  return [...byKey.values()];
}

function buildEncounterNoteDraft({ title, summary, severity, evidence = [], suggestedQuestions = [], suggestedActions = [] }) {
  const lines = [
    `PGHD review: ${title}`,
    `Severity: ${severity}`,
    '',
    `Summary: ${summary}`,
    ''
  ];

  if (evidence.length) {
    lines.push('Evidence:');
    for (const item of evidence.slice(0, 5)) lines.push(`- ${item}`);
    lines.push('');
  }

  if (suggestedQuestions.length) {
    lines.push('Questions for encounter:');
    for (const item of suggestedQuestions.slice(0, 3)) lines.push(`- ${item}`);
    lines.push('');
  }

  if (suggestedActions.length) {
    lines.push('Review actions:');
    for (const item of suggestedActions.slice(0, 3)) lines.push(`- ${item}`);
    lines.push('');
  }

  lines.push('Clinical note: PGHD-derived context only. Review with the client before changing the plan.');
  return lines.join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

function makeInsight({ insightType, severity, title, summary, snapshots, evidence = [], suggestedQuestions = [], suggestedActions = [] }) {
  const first = snapshots.find(Boolean) || {};
  const cleanEvidence = evidence.filter(Boolean);
  const cleanQuestions = suggestedQuestions.filter(Boolean);
  const cleanActions = suggestedActions.filter(Boolean);
  const activities = sourceActivityRefs(snapshots);
  return compactObject({
    insightType,
    severity,
    title,
    summary,
    providerSource: providerSource(first),
    windowStart: first.windowStart || first.window_start,
    windowEnd: first.windowEnd || first.window_end,
    confidence: confidenceFromSnapshots(snapshots),
    evidence: cleanEvidence,
    suggestedQuestions: cleanQuestions,
    suggestedActions: cleanActions,
    noteDraft: buildEncounterNoteDraft({
      title,
      summary,
      severity,
      evidence: cleanEvidence,
      suggestedQuestions: cleanQuestions,
      suggestedActions: cleanActions
    }),
    sourceSnapshots: sourceSnapshotRefs(snapshots),
    sourceActivities: activities.length ? activities.slice(0, 10) : undefined
  });
}

function qualityEvidence(snapshot) {
  const meta = metadata(snapshot);
  if (!meta.dataQuality || meta.dataQuality === 'supported') return [];
  const reasons = Array.isArray(meta.insufficientDataReasons) ? meta.insufficientDataReasons : [];
  return [
    `data quality is ${meta.dataQuality}`,
    reasons.length ? `insufficient data reasons: ${reasons.join(', ')}` : ''
  ].filter(Boolean);
}

function trendEvidence(snapshot) {
  const meta = metadata(snapshot);
  return [
    meta.volumeTrend ? `volume trend ${meta.volumeTrend}` : '',
    meta.totalKmDelta !== undefined ? `weekly distance delta ${meta.totalKmDelta} km` : '',
    meta.adherenceTrend ? `adherence trend ${meta.adherenceTrend}` : '',
    meta.runCountDelta !== undefined ? `run count delta ${meta.runCountDelta}` : ''
  ].filter(Boolean);
}

function buildProviderInsights(providerSnapshots) {
  const byType = latestSnapshotsByType(providerSnapshots);
  const trainingLoad = byType.get('training_load');
  const adherence = byType.get('adherence');
  const fatigue = byType.get('fatigue');
  const insights = [];

  const fatigueValue = toNumber(fatigue?.value);
  const loadValue = toNumber(trainingLoad?.value);
  const adherenceValue = toNumber(adherence?.value);
  const loadRatio = toNumber(metadata(fatigue || trainingLoad || {}).loadRatio);

  if (fatigue && fatigueValue !== null && fatigueValue >= 0.75) {
    insights.push(makeInsight({
      insightType: 'load_review',
      severity: 'alert',
      title: 'Review recent load before progressing the plan',
      summary: 'Fatigue is high enough that the next encounter should review recent volume, recovery, and symptoms before increasing training.',
      snapshots: [fatigue, trainingLoad].filter(Boolean),
      evidence: [
        `fatigue ${Math.round(fatigueValue * 100)}%`,
        loadValue !== null ? `training load ${Math.round(loadValue * 100)}%` : '',
        loadRatio !== null ? `load ratio ${loadRatio}` : '',
        ...trendEvidence(fatigue),
        ...qualityEvidence(fatigue)
      ],
      suggestedQuestions: [
        'Any soreness, pain, poor sleep, or unusual effort since the last run?',
        'Should the next planned session be reduced or shifted to recovery?'
      ],
      suggestedActions: [
        'Review the source activity events before changing the plan.',
        'Avoid presenting this signal as a diagnosis or treatment recommendation.'
      ]
    }));
  } else if (fatigue && fatigueValue !== null && fatigueValue >= 0.55) {
    insights.push(makeInsight({
      insightType: 'fatigue_monitoring',
      severity: 'warning',
      title: 'Monitor fatigue trend',
      summary: 'Fatigue is elevated. Use the encounter to confirm whether this reflects productive load or insufficient recovery.',
      snapshots: [fatigue, trainingLoad].filter(Boolean),
      evidence: [
        `fatigue ${Math.round(fatigueValue * 100)}%`,
        loadValue !== null ? `training load ${Math.round(loadValue * 100)}%` : '',
        ...trendEvidence(fatigue),
        ...qualityEvidence(fatigue)
      ],
      suggestedQuestions: [
        'Did the latest week feel harder than expected?',
        'Any recovery constraints that should change this week’s target?'
      ],
      suggestedActions: ['Check prior-week comparison and source event traceability.']
    }));
  }

  if (adherence && adherenceValue !== null && adherenceValue < 0.5) {
    insights.push(makeInsight({
      insightType: 'adherence_gap',
      severity: adherenceValue < 0.25 ? 'alert' : 'warning',
      title: 'Address adherence gap',
      summary: 'Run frequency is below the configured weekly target. The next encounter should clarify barriers before changing intensity.',
      snapshots: [adherence],
      evidence: [
        `adherence ${Math.round(adherenceValue * 100)}%`,
        metadata(adherence).runCount !== undefined ? `run count ${metadata(adherence).runCount}` : '',
        metadata(adherence).targetRunsPerWeek !== undefined ? `target ${metadata(adherence).targetRunsPerWeek}` : '',
        ...trendEvidence(adherence),
        ...qualityEvidence(adherence)
      ],
      suggestedQuestions: [
        'What prevented the planned sessions from happening?',
        'Should the weekly target be adjusted for schedule, symptoms, or motivation?'
      ],
      suggestedActions: ['Separate plan adherence from fitness or recovery conclusions.']
    }));
  }

  if ((trainingLoad || fatigue) && loadRatio !== null && loadRatio >= 1.3) {
    insights.push(makeInsight({
      insightType: 'load_ramp',
      severity: loadRatio >= 1.6 ? 'alert' : 'warning',
      title: 'Recent load increased quickly',
      summary: 'The latest week is materially higher than the available prior baseline, so progression should be discussed explicitly.',
      snapshots: [trainingLoad, fatigue].filter(Boolean),
      evidence: [
        `load ratio ${loadRatio}`,
        metadata(trainingLoad || fatigue).priorKmAverage !== undefined
          ? `prior average ${metadata(trainingLoad || fatigue).priorKmAverage} km`
          : '',
        ...trendEvidence(trainingLoad || fatigue),
        ...qualityEvidence(trainingLoad || fatigue)
      ],
      suggestedQuestions: [
        'Was the increase planned, accidental, or caused by a race/event?',
        'Any early warning signs after the higher-load week?'
      ],
      suggestedActions: ['Use the activity-event list to inspect which runs drove the increase.']
    }));
  }

  const limitedQuality = [...byType.values()].filter((snapshot) => {
    const level = metadata(snapshot).dataQuality;
    return level === 'limited' || level === 'partial';
  });
  if (limitedQuality.length && !insights.some((insight) => insight.insightType === 'data_quality_note')) {
    insights.push(makeInsight({
      insightType: 'data_quality_note',
      severity: 'info',
      title: 'Interpret state signals with data-quality context',
      summary: 'One or more state signals are based on limited history or incomplete weekly data. Treat them as conversation starters, not conclusions.',
      snapshots: limitedQuality,
      evidence: limitedQuality.flatMap(qualityEvidence),
      suggestedQuestions: ['Is the client using all expected data sources consistently?'],
      suggestedActions: ['Confirm missing or short-history data before escalating clinical significance.']
    }));
  }

  if (!insights.length && byType.size) {
    insights.push(makeInsight({
      insightType: 'state_review',
      severity: 'info',
      title: 'Review current activity state',
      summary: 'Current state signals are available for the encounter. Use the linked activity events to ground the discussion.',
      snapshots: [...byType.values()],
      evidence: [...byType.values()].map((snapshot) => `${stateType(snapshot)} ${Math.round(Number(snapshot.value || 0) * 100)}%`),
      suggestedQuestions: ['Does the current activity pattern match the client’s plan and perceived effort?'],
      suggestedActions: ['Use this as encounter context rather than automated clinical advice.']
    }));
  }

  return insights;
}

export function buildEncounterInsights(snapshots, opts = {}) {
  const rows = Array.isArray(snapshots) ? snapshots.filter(Boolean) : [];
  const grouped = new Map();

  for (const snapshot of rows) {
    const key = [
      snapshot.subjectPersonId || snapshot.subject_person_id || opts.subjectPersonId || '',
      snapshot.organizationId || snapshot.organization_id || opts.organizationId || '',
      snapshot.orgClientProfileId || snapshot.org_client_profile_id || opts.orgClientProfileId || '',
      providerSource(snapshot)
    ].join('|');
    const group = grouped.get(key) || [];
    group.push(snapshot);
    grouped.set(key, group);
  }

  return [...grouped.values()].flatMap(buildProviderInsights);
}
