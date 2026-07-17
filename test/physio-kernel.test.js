import assert from 'node:assert/strict';
import { test } from 'node:test';

import { appendRunToPhysioKernel } from '../lib/physio-kernel.js';

const RUN = {
  source: 'strava',
  externalId: '12345',
  name: 'Morning Run',
  startDate: '2026-07-17T00:15:00.000Z',
  movingTimeSec: 1800,
  distanceMeters: 5000,
  averageHeartrate: 148
};

const ENV = {
  PHYSIO_APP_BASE_URL: 'https://kinelo.example',
  KERNEL_API_V0_SHARED_TOKEN: 'secret-token',
  KERNEL_API_V0_ORGANIZATION_ID: '11111111-1111-4111-8111-111111111111',
  KERNEL_API_V0_SERVICE_ACCOUNT_ID: 'strava-run-log',
  KERNEL_API_V0_SCOPES: 'events:append,timeline:read',
  HM1C_DOGFOOD_SUBJECT_PERSON_ID: '22222222-2222-4222-8222-222222222222',
  HM1C_DOGFOOD_ORGANIZATION_ID: '11111111-1111-4111-8111-111111111111',
  HM1C_DOGFOOD_ALLOWED_SOURCES: 'strava'
};

test('appendRunToPhysioKernel sends one tenant-scoped PGHD event', async () => {
  // Given
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return new Response(
      JSON.stringify({
        success: true,
        data: { persisted: true, activityEventId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' }
      }),
      {
      status: 200,
      headers: { 'content-type': 'application/json' }
      }
    );
  };

  // When
  const result = await appendRunToPhysioKernel(RUN, { env: ENV, fetchImpl });

  // Then
  assert.equal(result.persisted, true);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://kinelo.example/api/kernel/v0');
  assert.equal(calls[0].init.headers.authorization, 'Bearer secret-token');
  const body = JSON.parse(calls[0].init.body);
  assert.equal(body.domain, 'events');
  assert.equal(body.eventName, 'pghd.strava.activity_completed');
  assert.equal(body.subjectPersonId, ENV.HM1C_DOGFOOD_SUBJECT_PERSON_ID);
  assert.equal(body.context.organizationId, ENV.KERNEL_API_V0_ORGANIZATION_ID);
  assert.equal(body.payload.externalId, 'strava:12345');
  assert.equal(body.payload.startedAt, RUN.startDate);
});

test('appendRunToPhysioKernel fails closed when configuration is incomplete', async () => {
  // Given
  const env = { ...ENV, KERNEL_API_V0_SHARED_TOKEN: '' };

  // When / Then
  await assert.rejects(
    appendRunToPhysioKernel(RUN, { env, fetchImpl: async () => new Response() }),
    /KERNEL_API_V0_SHARED_TOKEN/
  );
});

test('appendRunToPhysioKernel rejects owner scope drift', async () => {
  // Given
  const env = {
    ...ENV,
    HM1C_DOGFOOD_ORGANIZATION_ID: '33333333-3333-4333-8333-333333333333'
  };

  // When / Then
  await assert.rejects(
    appendRunToPhysioKernel(RUN, { env, fetchImpl: async () => new Response() }),
    /must match HM-1c dogfood organization/
  );
});

test('appendRunToPhysioKernel surfaces a rejected kernel write', async () => {
  // Given
  const fetchImpl = async () => new Response(JSON.stringify({ error: 'forbidden' }), { status: 403 });

  // When / Then
  await assert.rejects(
    appendRunToPhysioKernel(RUN, { env: ENV, fetchImpl }),
    /Kernel API rejected Strava activity: 403/
  );
});

test('appendRunToPhysioKernel rejects a non-HTTPS destination', async () => {
  // Given
  const env = { ...ENV, PHYSIO_APP_BASE_URL: 'http://kinelo.example' };

  // When / Then
  await assert.rejects(
    appendRunToPhysioKernel(RUN, { env, fetchImpl: async () => new Response() }),
    /must use HTTPS/
  );
});

test('appendRunToPhysioKernel requires the persisted event identifier', async () => {
  // Given
  const fetchImpl = async () => Response.json({ success: true, data: { persisted: true } });

  // When / Then
  await assert.rejects(
    appendRunToPhysioKernel(RUN, { env: ENV, fetchImpl }),
    /missing activityEventId/
  );
});
