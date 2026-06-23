import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { makeSubjectId as makeDbSmokeSubjectId } from '../scripts/smoke_pghd_state_db.mjs';
import {
  assertSnapshotsHaveInputs,
  makeSubjectId as makeMaterializationSmokeSubjectId
} from '../scripts/smoke_pghd_state_materialization.mjs';
import {
  assertOrgClientContextSelection,
  buildPreflightEvidence,
  shouldBootstrapOrgClient,
  shouldMaterializeSmokeState
} from '../scripts/smoke_pghd_e2e.mjs';
import { buildSmokeCleanupReport } from '../scripts/check_pghd_smoke_cleanup.mjs';
import { checkPhysioHandoffSurface } from '../scripts/check_pghd_physio_handoff_readiness.mjs';

test('state smoke scripts can be imported without executing remote work', () => {
  assert.equal(makeDbSmokeSubjectId('20260622155633762'), '11111111-1111-4111-8111-622155633762');
  assert.equal(makeMaterializationSmokeSubjectId('20260622155633762'), '11111111-1111-4111-8111-622155633762');
});

test('state materialization smoke validates traceability inputs', () => {
  assert.doesNotThrow(() => assertSnapshotsHaveInputs([
    {
      stateType: 'training_load',
      inputs: [{ runLogRunId: 'run-001', weight: 1 }]
    }
  ], 'materialized'));

  assert.throws(
    () => assertSnapshotsHaveInputs([{ stateType: 'fatigue', inputs: [] }], 'read-back'),
    /read-back snapshots missing traceability inputs: fatigue/
  );
});

test('PGHD E2E smoke preflight evidence carries warning details and next actions', () => {
  const evidence = buildPreflightEvidence({
    summary: { status: 'warning' },
    checks: [
      { name: 'connection_mapping', status: 'ok', message: 'mapped' },
      {
        name: 'physio_person_context',
        status: 'warning',
        message: 'PhysioApp person exists but no org client profile was found.',
        operatorHints: ['Register the person as an org client before expecting encounter-room PGHD handoff.']
      }
    ],
    nextActions: ['Register the person as an org client before expecting encounter-room PGHD handoff.']
  });

  assert.equal(evidence.preflightStatus, 'warning');
  assert.deepEqual(evidence.preflightChecks, {
    connection_mapping: 'ok',
    physio_person_context: 'warning'
  });
  assert.deepEqual(evidence.preflightWarnings, [
    {
      name: 'physio_person_context',
      status: 'warning',
      message: 'PhysioApp person exists but no org client profile was found.',
      operatorHints: ['Register the person as an org client before expecting encounter-room PGHD handoff.']
    }
  ]);
  assert.deepEqual(evidence.preflightNextActions, [
    'Register the person as an org client before expecting encounter-room PGHD handoff.'
  ]);
});

test('PGHD E2E smoke can require an org-client subject in strict staging mode', () => {
  assert.doesNotThrow(() => assertOrgClientContextSelection(
    { hasOrgClientContext: false },
    { PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT: '0' }
  ));
  assert.doesNotThrow(() => assertOrgClientContextSelection(
    { hasOrgClientContext: true },
    { PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT: '1' }
  ));
  assert.throws(
    () => assertOrgClientContextSelection(
      { hasOrgClientContext: false },
      { PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT: '1' }
    ),
    /requires an org-client subject/
  );
});

test('PGHD E2E smoke org-client bootstrap is explicit opt-in', () => {
  assert.equal(shouldBootstrapOrgClient({}), false);
  assert.equal(shouldBootstrapOrgClient({ PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT: '0' }), false);
  assert.equal(shouldBootstrapOrgClient({ PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT: '1' }), true);
  assert.equal(shouldBootstrapOrgClient({ PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT: 'true' }), true);
  assert.equal(shouldMaterializeSmokeState({}), false);
  assert.equal(shouldMaterializeSmokeState({ PGHD_SMOKE_MATERIALIZE_STATE: '0' }), false);
  assert.equal(shouldMaterializeSmokeState({ PGHD_SMOKE_MATERIALIZE_STATE: '1' }), true);
});

test('PGHD smoke cleanup report fails on leftover artifacts', () => {
  assert.deepEqual(
    buildSmokeCleanupReport({
      bootstrapConnections: [],
      smokeRuns: [],
      activeSmokePersons: []
    }),
    {
      ok: true,
      leftoverBootstrapConnections: 0,
      leftoverSmokeRuns: 0,
      activeSmokePersons: 0,
      samples: {
        bootstrapConnections: [],
        smokeRuns: [],
        activeSmokePersons: []
      }
    }
  );

  const report = buildSmokeCleanupReport({
    bootstrapConnections: [{ id: 'conn-1', provider_user_id: 'pghd-smoke-bootstrap-1' }],
    smokeRuns: [{ id: 'run-1', external_id: 'apple_health_pghd_smoke_1' }],
    activeSmokePersons: [{ id: 'person-1', first_name: 'PGHD', last_name: 'Smoke-1' }]
  });

  assert.equal(report.ok, false);
  assert.equal(report.leftoverBootstrapConnections, 1);
  assert.equal(report.leftoverSmokeRuns, 1);
  assert.equal(report.activeSmokePersons, 1);
});

test('PGHD E2E smoke verifies preflight readiness', () => {
  const script = readFileSync(new URL('../scripts/smoke_pghd_e2e.mjs', import.meta.url), 'utf8');
  const readme = readFileSync(new URL('../README.md', import.meta.url), 'utf8');
  const apiContract = readFileSync(new URL('../docs/physio-app-api-contract.md', import.meta.url), 'utf8');

  assert.match(script, /api\/run-log\/preflight/);
  assert.match(script, /preflight checked readiness/);
  assert.match(script, /connectionSelectionMode/);
  assert.match(script, /selectedOrgClientContext/);
  assert.match(script, /PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT/);
  assert.match(script, /PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT/);
  assert.match(script, /PGHD_SMOKE_MATERIALIZE_STATE/);
  assert.match(script, /requires PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT/);
  assert.match(script, /preflightChecks/);
  assert.match(script, /preflightWarnings/);
  assert.match(script, /preflightNextActions/);
  assert.match(script, /physio_person_context/);
  assert.match(script, /connection_mapping/);
  assert.match(script, /activity_ingest/);
  assert.match(script, /weekly_summary/);
  assert.match(script, /state_materialization/);
  const cleanupScript = readFileSync(new URL('../scripts/check_pghd_smoke_cleanup.mjs', import.meta.url), 'utf8');
  assert.match(cleanupScript, /pghd-smoke-bootstrap/);
  assert.match(cleanupScript, /apple_health_pghd_smoke/);
  assert.match(readme, /preflightChecks/);
  assert.match(readme, /preflightWarnings/);
  assert.match(readme, /preflightNextActions/);
  assert.match(readme, /connectionSelectionMode/);
  assert.match(readme, /selectedOrgClientContext/);
  assert.match(readme, /PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT/);
  assert.match(readme, /smoke:pghd:strict-org-client/);
  assert.match(readme, /smoke:pghd:strict-full/);
  assert.match(readme, /gate:pghd:strict-staging/);
  assert.match(apiContract, /evidence\.preflightChecks/);
  assert.match(apiContract, /evidence\.preflightWarnings/);
  assert.match(apiContract, /evidence\.preflightNextActions/);
  assert.match(apiContract, /evidence\.connectionSelectionMode/);
  assert.match(apiContract, /evidence\.selectedOrgClientContext/);
  assert.match(apiContract, /PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT/);
  assert.match(apiContract, /smoke:pghd:strict-org-client/);
  assert.match(apiContract, /smoke:pghd:strict-full/);
  assert.match(apiContract, /gate:pghd:strict-staging/);
});

test('PGHD execution roadmap documents release gates and db push guardrail', () => {
  const readme = readFileSync(new URL('../README.md', import.meta.url), 'utf8');
  const improvementPlan = readFileSync(new URL('../docs/pghd-improvement-plan.md', import.meta.url), 'utf8');
  const roadmap = readFileSync(new URL('../docs/pghd-execution-roadmap.md', import.meta.url), 'utf8');
  const decision = readFileSync(
    new URL('../docs/pghd-release-decision-working-tree-2026-06-23.md', import.meta.url),
    'utf8'
  );

  assert.match(readme, /docs\/pghd-execution-roadmap\.md/);
  assert.match(readme, /pghd-release-decision-working-tree-2026-06-23\.md/);
  assert.match(improvementPlan, /pghd-execution-roadmap\.md/);
  assert.match(roadmap, /Do not run broad `supabase db push` from this repo/);
  assert.match(roadmap, /PhysioApp owner-lineage bridge path/);
  assert.match(roadmap, /npm run gate:pghd:release/);
  assert.match(roadmap, /npm run gate:pghd:physio-release/);
  assert.match(roadmap, /npm run gate:pghd:strict-staging/);
  assert.match(roadmap, /npm run check:pghd:smoke-cleanup/);
  assert.match(roadmap, /npm run report:pghd:release-decision/);
  assert.match(roadmap, /npm run gate:pghd:decision/);
  assert.match(roadmap, /pghd-release-decision-working-tree-2026-06-23\.md/);
  assert.match(decision, /ready_for_release_review/);
  assert.match(decision, /physio-app-owner-lineage/);
  assert.match(decision, /missingGateEvidence: \[\]/);
  assert.match(decision, /blockers: \[\]/);
  assert.match(decision, /Broad `supabase db push` from `strava-run-log` remains blocked/);
});

test('package PGHD release gate chains unit, UI, E2E, and apply-path checks', () => {
  const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

  assert.equal(
    packageJson.scripts['gate:pghd:release'],
    'npm test && npm run smoke:dashboard:viewport && npm run smoke:pghd && npm run check:pghd:smoke-cleanup && npm run check:pghd:release-readiness'
  );
});

test('package exposes combined PGHD Physio handoff readiness check', () => {
  const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

  assert.equal(
    packageJson.scripts['check:pghd:physio-handoff'],
    'node scripts/check_pghd_physio_handoff_readiness.mjs'
  );
  assert.equal(
    packageJson.scripts['check:pghd:smoke-cleanup'],
    'node scripts/check_pghd_smoke_cleanup.mjs'
  );
});

test('package exposes full PGHD Physio release gate', () => {
  const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

  assert.equal(
    packageJson.scripts['gate:pghd:physio-release'],
    'npm run gate:pghd:release && npm run check:pghd:physio-handoff -- --static-only'
  );
  assert.equal(
    packageJson.scripts['gate:pghd:strict-staging'],
    'npm run smoke:pghd:strict-full && npm run check:pghd:physio-handoff -- --static-only && npm run check:pghd:smoke-cleanup'
  );
  assert.equal(
    packageJson.scripts['report:pghd:release-decision'],
    'node scripts/report_pghd_release_decision.mjs'
  );
  assert.equal(
    packageJson.scripts['gate:pghd:decision'],
    'node scripts/run_pghd_release_decision.mjs'
  );
});

test('package exposes strict PGHD staging smoke scripts', () => {
  const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

  assert.equal(
    packageJson.scripts['smoke:pghd:strict-org-client'],
    'PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT=1 PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT=1 node scripts/smoke_pghd_e2e.mjs'
  );
  assert.equal(
    packageJson.scripts['smoke:pghd:strict-full'],
    'PGHD_SMOKE_BOOTSTRAP_ORG_CLIENT=1 PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT=1 PGHD_SMOKE_MATERIALIZE_STATE=1 node scripts/smoke_pghd_e2e.mjs'
  );
});

test('Physio handoff surface checker reports missing contract strings', () => {
  const checks = checkPhysioHandoffSurface(new URL('.', import.meta.url).pathname);

  assert.equal(checks.length > 0, true);
  assert.equal(checks.every((check) => check.ok), false);
  assert.equal(checks.some((check) => check.missing.includes('file')), true);
});
