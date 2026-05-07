import assert from 'node:assert/strict';
import test from 'node:test';

import { buildLiveCoachingDecision, buildPostRunCoaching } from '../lib/coaching.js';

test('live coaching asks for more data when pace is missing', () => {
  const decision = buildLiveCoachingDecision(
    { paceSec: 0, hr: 0, distanceKm: 0, elapsedSec: 0 },
    { targetPaceSec: 370, nextCheckSec: 45 }
  );

  assert.equal(decision.severity, 'info');
  assert.equal(decision.action, 'maintain');
  assert.equal(decision.nextCheckSec, 45);
  assert.equal(decision.adjustedTargetPaceSec, 370);
});

test('readiness score softens the target pace', () => {
  const decision = buildLiveCoachingDecision(
    { paceSec: 378, hr: 150, distanceKm: 1.5, elapsedSec: 600 },
    { targetPaceSec: 370, readinessScore: 65 }
  );

  assert.equal(decision.adjustedTargetPaceSec, 378);
  assert.equal(decision.severity, 'info');
  assert.equal(decision.action, 'maintain');
});

test('fast pace triggers slow down guidance', () => {
  const decision = buildLiveCoachingDecision(
    { paceSec: 340, hr: 150, distanceKm: 1.0, elapsedSec: 360 },
    { targetPaceSec: 370 }
  );

  assert.equal(decision.severity, 'warn');
  assert.equal(decision.action, 'slow_down');
  assert.equal(decision.adjustedTargetPaceSec, 370);
});

test('sustained high heart rate escalates to stop guidance', () => {
  const decision = buildLiveCoachingDecision(
    { paceSec: 370, hr: 180, distanceKm: 2.5, elapsedSec: 120 },
    { targetPaceSec: 370, maxHr: 175, hrSustainedSec: 120 }
  );

  assert.equal(decision.severity, 'alert');
  assert.equal(decision.action, 'stop');
  assert.match(decision.text, /Stop/);
});

test('post-run coaching falls back cleanly when activity distance is missing', () => {
  const text = buildPostRunCoaching(
    { name: 'No distance run', distance: 0, moving_time: 0 },
    { targetPaceSec: 370 }
  );

  assert.match(text, /6:10\/km/);
});
