import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildWeeklyActivityStateSnapshots, snapshotRowToApi } from '../lib/human-state.js';

test('buildWeeklyActivityStateSnapshots derives activity states from weekly summaries', () => {
  const snapshots = buildWeeklyActivityStateSnapshots(
    [
      {
        week_start: '2026-06-08',
        subject_person_id: '11111111-1111-4111-8111-111111111111',
        source: 'apple-health',
        total_km: 12,
        moving_time_sec: 4200,
        run_count: 2,
        first_run_at: '2026-06-09T06:00:00Z',
        last_run_at: '2026-06-13T06:00:00Z',
        average_pace_sec_per_km: 350,
        average_heartrate: 146,
        average_cadence: 170
      },
      {
        week_start: '2026-06-15',
        subject_person_id: '11111111-1111-4111-8111-111111111111',
        source: 'apple-health',
        total_km: 18,
        moving_time_sec: 6300,
        run_count: 3,
        first_run_at: '2026-06-16T06:00:00Z',
        last_run_at: '2026-06-20T06:00:00Z',
        average_pace_sec_per_km: 350,
        average_heartrate: 150,
        average_cadence: 172
      }
    ],
    {
      calculatedAt: '2026-06-22T00:00:00Z',
      targetRunsPerWeek: 3
    }
  );

  assert.equal(snapshots.length, 3);
  assert.deepEqual(
    snapshots.map((snapshot) => snapshot.stateType),
    ['training_load', 'adherence', 'fatigue']
  );
  assert.equal(snapshots[0].subjectPersonId, '11111111-1111-4111-8111-111111111111');
  assert.equal(snapshots[0].providerSource, 'apple-health');
  assert.equal(snapshots[1].value, 1);
  assert.equal(snapshots[2].metadata.loadRatio, 1.5);
  assert.equal(snapshots[0].metadata.totalKmDelta, 6);
  assert.equal(snapshots[0].metadata.movingMinutesDelta, 35);
  assert.equal(snapshots[1].metadata.runCountDelta, 1);
  assert.equal(snapshots[2].metadata.volumeTrend, 'up');
  assert.equal(snapshots[0].metadata.dataQuality, 'partial');
  assert.equal(snapshots[0].metadata.hasPriorBaseline, true);
  assert.equal(snapshots[0].metadata.sourceActivityCount, 3);
  assert.equal(snapshots[0].metadata.latestRunAt, '2026-06-20T06:00:00Z');
  assert.deepEqual(snapshots[0].metadata.metricCoverage, {
    pace: true,
    heartRate: true,
    cadence: true
  });
  assert.equal(snapshots[0].metadata.missingMetricReasons, undefined);
  assert.deepEqual(snapshots[0].metadata.insufficientDataReasons, ['short_history']);
});

test('snapshotRowToApi maps database rows and traceability inputs', () => {
  const api = snapshotRowToApi(
    {
      id: 'snapshot-001',
      subject_person_id: '11111111-1111-4111-8111-111111111111',
      state_type: 'fatigue',
      value: 0.62,
      confidence: 0.7,
      calculated_at: '2026-06-22T00:00:00Z',
      window_start: '2026-06-15T00:00:00Z',
      window_end: '2026-06-22T00:00:00Z',
      source: 'run_log_weekly_summaries',
      provider_source: 'apple-health',
      metadata: { loadRatio: 1.5 }
    },
    [{ run_log_run_id: 'run-001', weight: 1 }]
  );

  assert.equal(api.stateType, 'fatigue');
  assert.equal(api.subjectPersonId, '11111111-1111-4111-8111-111111111111');
  assert.equal(api.providerSource, 'apple-health');
  assert.deepEqual(api.inputs, [{ runLogRunId: 'run-001', weight: 1 }]);
});

test('buildWeeklyActivityStateSnapshots keeps provider source separate from calculation source', () => {
  const apple = buildWeeklyActivityStateSnapshots([
    {
      week_start: '2026-06-15',
      subject_person_id: '11111111-1111-4111-8111-111111111111',
      source: 'apple-health',
      total_km: 10,
      moving_time_sec: 3600,
      run_count: 2,
      last_run_at: '2026-06-20T06:00:00Z'
    }
  ]);
  const strava = buildWeeklyActivityStateSnapshots([
    {
      week_start: '2026-06-15',
      subject_person_id: '11111111-1111-4111-8111-111111111111',
      source: 'strava',
      total_km: 8,
      moving_time_sec: 3000,
      run_count: 1,
      last_run_at: '2026-06-20T06:00:00Z'
    }
  ]);

  assert.equal(apple[0].source, 'run_log_weekly_summaries');
  assert.equal(strava[0].source, 'run_log_weekly_summaries');
  assert.equal(apple[0].providerSource, 'apple-health');
  assert.equal(strava[0].providerSource, 'strava');
});

test('buildWeeklyActivityStateSnapshots marks limited history when baseline is missing', () => {
  const snapshots = buildWeeklyActivityStateSnapshots([
    {
      week_start: '2026-06-15',
      subject_person_id: '11111111-1111-4111-8111-111111111111',
      source: 'apple-health',
      total_km: 6,
      moving_time_sec: 1800,
      run_count: 1,
      last_run_at: '2026-06-20T06:00:00Z'
    }
  ]);

  assert.equal(snapshots.length, 3);
  for (const snapshot of snapshots) {
    assert.equal(snapshot.metadata.dataQuality, 'limited');
    assert.equal(snapshot.metadata.dataQualityWeekCount, 1);
    assert.equal(snapshot.metadata.hasPriorBaseline, false);
    assert.equal(snapshot.metadata.sourceActivityCount, 1);
    assert.deepEqual(snapshot.metadata.metricCoverage, {
      pace: false,
      heartRate: false,
      cadence: false
    });
    assert.deepEqual(snapshot.metadata.missingMetricReasons, [
      'missing_average_pace',
      'missing_average_heartrate',
      'missing_average_cadence'
    ]);
    assert.equal(snapshot.metadata.totalKmDelta, undefined);
    assert.equal(snapshot.metadata.runCountDelta, undefined);
    assert.ok(snapshot.metadata.insufficientDataReasons.includes('missing_prior_baseline'));
    assert.ok(snapshot.metadata.insufficientDataReasons.includes('limited_load_comparison'));
    assert.ok(snapshot.confidence <= 0.45);
  }
});

test('buildWeeklyActivityStateSnapshots derives states per provider source', () => {
  const snapshots = buildWeeklyActivityStateSnapshots([
    {
      week_start: '2026-06-15',
      subject_person_id: '11111111-1111-4111-8111-111111111111',
      source: 'apple-health',
      total_km: 10,
      moving_time_sec: 3600,
      run_count: 2,
      last_run_at: '2026-06-20T06:00:00Z'
    },
    {
      week_start: '2026-06-15',
      subject_person_id: '11111111-1111-4111-8111-111111111111',
      source: 'strava',
      total_km: 8,
      moving_time_sec: 3000,
      run_count: 1,
      last_run_at: '2026-06-19T06:00:00Z'
    }
  ]);

  assert.equal(snapshots.length, 6);
  assert.deepEqual(
    [...new Set(snapshots.map((snapshot) => snapshot.providerSource))].sort(),
    ['apple-health', 'strava']
  );
});
