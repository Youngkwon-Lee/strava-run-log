import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildEncounterInsights } from '../lib/encounter-insights.js';

test('buildEncounterInsights turns high fatigue into encounter review guidance', () => {
  const insights = buildEncounterInsights([
    {
      id: 'snapshot-fatigue',
      subjectPersonId: '11111111-1111-4111-8111-111111111111',
      stateType: 'fatigue',
      value: 0.82,
      confidence: 0.71,
      windowStart: '2026-06-15',
      windowEnd: '2026-06-21T06:00:00Z',
      source: 'run_log_weekly_summaries',
      providerSource: 'apple-health',
      inputs: [{
        runLogRunId: '55555555-5555-4555-8555-555555555555',
        pghdActivityEventId: '66666666-6666-4666-8666-666666666666',
        weight: 1,
        activity: {
          id: '55555555-5555-4555-8555-555555555555',
          pghdActivityEventId: '66666666-6666-4666-8666-666666666666',
          source: 'apple-health',
          externalId: 'apple-001',
          name: 'Morning rehab run',
          startedAt: '2026-06-18T01:00:00Z',
          distanceKm: 4.02,
          movingTimeSec: 1510
        }
      }],
      metadata: {
        loadRatio: 1.7,
        totalKmDelta: 14,
        volumeTrend: 'up',
        dataQuality: 'partial',
        dataQualityWeekCount: 3,
        hasPriorBaseline: true,
        sourceActivityCount: 4,
        latestRunAt: '2026-06-21T06:00:00Z',
        metricCoverage: {
          pace: true,
          heartRate: true,
          cadence: false
        },
        missingMetricReasons: ['missing_average_cadence'],
        insufficientDataReasons: ['short_history']
      }
    },
    {
      id: 'snapshot-load',
      subjectPersonId: '11111111-1111-4111-8111-111111111111',
      stateType: 'training_load',
      value: 0.68,
      confidence: 0.74,
      windowStart: '2026-06-15',
      windowEnd: '2026-06-21T06:00:00Z',
      source: 'run_log_weekly_summaries',
      providerSource: 'apple-health',
      metadata: {
        totalKm: 34,
        priorKmAverage: 20,
        totalKmDelta: 14,
        volumeTrend: 'up',
        dataQuality: 'partial',
        insufficientDataReasons: ['short_history']
      }
    }
  ]);

  assert.ok(insights.length >= 2);
  assert.equal(insights[0].insightType, 'load_review');
  assert.equal(insights[0].severity, 'alert');
  assert.equal(insights[0].providerSource, 'apple-health');
  assert.match(insights[0].summary, /next encounter/);
  assert.ok(insights[0].evidence.some((item) => item.includes('fatigue 82%')));
  assert.ok(insights[0].evidence.some((item) => item.includes('weekly distance delta 14 km')));
  assert.match(insights[0].noteDraft, /PGHD review: Review recent load/);
  assert.match(insights[0].noteDraft, /Clinical note: PGHD-derived context only/);
  assert.ok(insights[0].sourceSnapshots.some((snapshot) => snapshot.volumeTrend === 'up'));
  assert.equal(insights[0].sourceSnapshots[0].sourceActivityCount, 4);
  assert.deepEqual(insights[0].sourceSnapshots[0].metricCoverage, {
    pace: true,
    heartRate: true,
    cadence: false
  });
  assert.deepEqual(insights[0].sourceSnapshots[0].missingMetricReasons, ['missing_average_cadence']);
  assert.equal(insights[0].sourceActivities[0].pghdActivityEventId, '66666666-6666-4666-8666-666666666666');
  assert.equal(insights[0].sourceActivities[0].name, 'Morning rehab run');
  assert.ok(insights.some((insight) => insight.insightType === 'load_ramp'));
});

test('buildEncounterInsights flags adherence gaps and data quality separately', () => {
  const insights = buildEncounterInsights([
    {
      subjectPersonId: '11111111-1111-4111-8111-111111111111',
      stateType: 'adherence',
      value: 0.333,
      confidence: 0.39,
      windowStart: '2026-06-15',
      source: 'run_log_weekly_summaries',
      providerSource: 'strava',
      metadata: {
        runCount: 1,
        targetRunsPerWeek: 3,
        runCountDelta: -2,
        adherenceTrend: 'down',
        dataQuality: 'limited',
        insufficientDataReasons: ['missing_prior_baseline', 'limited_load_comparison']
      }
    }
  ]);

  assert.equal(insights[0].insightType, 'adherence_gap');
  assert.equal(insights[0].severity, 'warning');
  assert.ok(insights[0].evidence.some((item) => item.includes('adherence trend down')));
  assert.ok(insights[0].suggestedQuestions.some((question) => question.includes('prevented')));
  assert.ok(insights.some((insight) => insight.insightType === 'data_quality_note'));
});
