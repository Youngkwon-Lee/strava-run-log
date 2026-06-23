import assert from 'node:assert/strict';
import { test } from 'node:test';
import { retryCount, retryDelayMs, runChecksWithRetries } from '../scripts/check_pghd_state_schema.mjs';

test('state schema check retry env values are bounded', () => {
  assert.equal(retryCount({ PGHD_SCHEMA_CHECK_RETRIES: '0' }), 1);
  assert.equal(retryCount({ PGHD_SCHEMA_CHECK_RETRIES: '12' }), 12);
  assert.equal(retryCount({ PGHD_SCHEMA_CHECK_RETRIES: '99' }), 30);

  assert.equal(retryDelayMs({ PGHD_SCHEMA_CHECK_RETRY_MS: '1' }), 250);
  assert.equal(retryDelayMs({ PGHD_SCHEMA_CHECK_RETRY_MS: '750' }), 750);
  assert.equal(retryDelayMs({ PGHD_SCHEMA_CHECK_RETRY_MS: '99999' }), 10000);
});

test('state schema check retries until all checks pass', async () => {
  let calls = 0;
  const slept = [];
  const result = await runChecksWithRetries({
    maxAttempts: 4,
    delayMs: 25,
    sleepFn: async (ms) => slept.push(ms),
    checkRunner: async () => {
      calls += 1;
      return [
        { name: 'activity-event columns', ok: calls >= 3 },
        { name: 'state tables', ok: calls >= 3 }
      ];
    }
  });

  assert.equal(calls, 3);
  assert.equal(result.attempts, 3);
  assert.equal(result.maxAttempts, 4);
  assert.deepEqual(slept, [25, 25]);
  assert.equal(result.checks.every((check) => check.ok), true);
});

test('state schema check stops at max attempts', async () => {
  let calls = 0;
  const slept = [];
  const result = await runChecksWithRetries({
    maxAttempts: 2,
    delayMs: 10,
    sleepFn: async (ms) => slept.push(ms),
    checkRunner: async () => {
      calls += 1;
      return [{ name: 'state tables', ok: false, error: 'missing table' }];
    }
  });

  assert.equal(calls, 2);
  assert.equal(result.attempts, 2);
  assert.deepEqual(slept, [10]);
  assert.equal(result.checks[0].ok, false);
});
