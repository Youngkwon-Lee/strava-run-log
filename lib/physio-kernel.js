const REQUIRED_ENV = [
  'PHYSIO_APP_BASE_URL',
  'KERNEL_API_V0_SHARED_TOKEN',
  'KERNEL_API_V0_ORGANIZATION_ID',
  'KERNEL_API_V0_SERVICE_ACCOUNT_ID',
  'KERNEL_API_V0_SCOPES',
  'HM1C_DOGFOOD_SUBJECT_PERSON_ID',
  'HM1C_DOGFOOD_ORGANIZATION_ID',
  'HM1C_DOGFOOD_ALLOWED_SOURCES'
];

function readConfig(env) {
  for (const key of REQUIRED_ENV) {
    if (!String(env[key] || '').trim()) throw new Error(`missing ${key}`);
  }

  const scopes = String(env.KERNEL_API_V0_SCOPES).split(',').map((scope) => scope.trim());
  const allowedSources = String(env.HM1C_DOGFOOD_ALLOWED_SOURCES)
    .split(',')
    .map((source) => source.trim().toLowerCase());
  if (!scopes.includes('events:append')) throw new Error('KERNEL_API_V0_SCOPES must include events:append');
  if (!allowedSources.includes('strava')) throw new Error('HM1C_DOGFOOD_ALLOWED_SOURCES must include strava');
  if (env.KERNEL_API_V0_ORGANIZATION_ID !== env.HM1C_DOGFOOD_ORGANIZATION_ID) {
    throw new Error('Kernel organization must match HM-1c dogfood organization');
  }
  const baseUrl = new URL(String(env.PHYSIO_APP_BASE_URL));
  if (baseUrl.protocol !== 'https:') throw new Error('PHYSIO_APP_BASE_URL must use HTTPS');

  return {
    baseUrl: baseUrl.href.replace(/\/$/, ''),
    token: String(env.KERNEL_API_V0_SHARED_TOKEN),
    organizationId: String(env.KERNEL_API_V0_ORGANIZATION_ID),
    subjectPersonId: String(env.HM1C_DOGFOOD_SUBJECT_PERSON_ID),
    serviceAccountId: String(env.KERNEL_API_V0_SERVICE_ACCOUNT_ID)
  };
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function requestTimeoutMs(env) {
  const parsed = Number(env.KERNEL_API_V0_TIMEOUT_MS || 8000);
  if (!Number.isFinite(parsed)) return 8000;
  return Math.min(20000, Math.max(1000, Math.trunc(parsed)));
}

export async function appendRunToPhysioKernel(run, options = {}) {
  const config = readConfig(options.env || process.env);
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  const externalId = String(run.externalId || run.id || '');
  const startedAt = run.startDate || run.startedAt;
  if (!externalId) throw new Error('missing run externalId');
  if (!startedAt) throw new Error('missing run startedAt');

  const response = await fetchImpl(`${config.baseUrl}/api/kernel/v0`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${config.token}`,
      'content-type': 'application/json'
    },
    signal: AbortSignal.timeout(requestTimeoutMs(options.env || process.env)),
    body: JSON.stringify({
      domain: 'events',
      eventName: 'pghd.strava.activity_completed',
      subjectPersonId: config.subjectPersonId,
      payload: compactObject({
        source: 'strava',
        externalId: `strava:${externalId}`,
        sourceRecordType: 'activity_event',
        activityType: run.activityType || run.sportType || run.type || 'running',
        name: run.name,
        startedAt,
        endedAt: run.endedAt,
        movingTimeSec: run.movingTimeSec,
        distanceMeters: run.distanceMeters,
        averageCadence: run.averageCadence,
        averageHeartrate: run.averageHeartrate,
        maxHeartrate: run.maxHeartrate,
        paceSecPerKm: run.paceSecPerKm,
        calories: run.calories
      }),
      context: {
        serviceAccountId: config.serviceAccountId,
        organizationId: config.organizationId,
        scopes: ['events:append']
      },
      provenance: {
        runtime: 'strava-run-log',
        requestId: `strava-webhook:${externalId}`
      }
    })
  });

  const body = await response.json().catch(() => null);
  if (!response.ok || body?.success !== true || body?.data?.persisted !== true) {
    throw new Error(`Kernel API rejected Strava activity: ${response.status}`);
  }
  if (!body.data.activityEventId) throw new Error('Kernel API response is missing activityEventId');

  return {
    persisted: true,
    activityEventId: body.data.activityEventId,
    organizationId: config.organizationId,
    subjectPersonId: config.subjectPersonId
  };
}
