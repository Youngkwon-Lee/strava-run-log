import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

test('dashboard inline scripts compile', () => {
  const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
  const scripts = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/gi)].map((match) => match[1]);

  assert.ok(scripts.length > 0);
  for (const script of scripts) {
    assert.doesNotThrow(() => new Function(script));
  }
});

test('dashboard exposes PGHD state snapshot API surface', () => {
  const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

  assert.match(html, /GET\/POST \/api\/run-log\/state-snapshots/);
  assert.match(html, /GET \/api\/run-log\/encounter-insights/);
  assert.match(html, /GET \/api\/run-log\/preflight/);
  assert.match(html, /POST \/api\/run-log\/encounter-note-drafts/);
  assert.match(html, /providerSource/);
  assert.match(html, /계산 소스/);
});

test('dashboard prioritizes PGHD human state over raw activity lists', () => {
  const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

  assert.match(html, /클라이언트 PGHD 상태/);
  assert.match(html, /PGHD Review Brief/);
  assert.match(html, /id="pghd-review-brief"/);
  assert.match(html, /id="pghd-brief-grid"/);
  assert.match(html, /Review priority/);
  assert.match(html, /id="pghd-brief-load"/);
  assert.match(html, /id="pghd-brief-fatigue"/);
  assert.match(html, /id="pghd-brief-adherence"/);
  assert.match(html, /Activity Event → Human State/);
  assert.match(html, /id="pghd-state-overview"/);
  assert.match(html, /현재 Human State/);
  assert.match(html, /Encounter Insight/);
  assert.match(html, /Encounter note draft/);
  assert.match(html, /초안 복사/);
  assert.match(html, /export row 생성/);
  assert.match(html, /Draft export preview/);
  assert.match(html, /export JSON 복사/);
  assert.match(html, /PhysioApp repositoryParams/);
  assert.match(html, /upsert payload 복사/);
  assert.match(html, /pghd-repository-json/);
  assert.match(html, /id="pghd-encounter"/);
  assert.match(html, /id="pghd-organization"/);
  assert.match(html, /id="pghd-provider"/);
  assert.match(html, /PGHD 운영 점검/);
  assert.match(html, /id="pghd-preflight-grid"/);
  assert.match(html, /fetchPghdPreflight/);
  assert.match(html, /renderPghdPreflight/);
  assert.match(html, /physio_person_context/);
  assert.match(html, /connection_mapping/);
  assert.match(html, /state_materialization/);
  assert.match(html, /근거 활동/);
  assert.match(html, /근거 활동 기록/);
  assert.match(html, /sourceActivities/);
  assert.match(html, /PGHD evidence/);
  assert.match(html, /buildPghdEvidenceSection/);
  assert.match(html, /formatSourceActivityEvidence/);
  assert.match(html, /formatEvidencePace/);
  assert.match(html, /source activity id/);
  assert.match(html, /runLogRunId/);
  assert.match(html, /pghdActivityEventId/);
  assert.match(html, /input\.activity\?\.name/);
  assert.match(html, /formatEvidenceDistance/);
  assert.match(html, /formatEvidenceDate/);
  assert.match(html, /weight/);
  assert.match(html, /pghd-source-evidence/);
  assert.match(html, /데이터 품질/);
  assert.match(html, /주간 변화/);
  assert.match(html, /제한 사유/);
  assert.match(html, /현재 Human State 없음/);
  assert.match(html, /상태 신호 없음/);
  assert.match(html, /주간 활동 근거 없음/);
  assert.match(html, /타임라인 기록 없음/);
  assert.match(html, /subject_person_id 연결/);
  assert.match(html, /provider ingest 상태/);
  assert.match(html, /pghdEmptyBody/);
  assert.match(html, /pghdEmptyAction/);
  assert.match(html, /emptyMessage/);
  assert.match(html, /operatorHints/);
  assert.ok(html.indexOf('PGHD Review Brief') < html.indexOf('주간 활동 분석'));
  assert.ok(html.indexOf('PGHD Review Brief') < html.indexOf('최근 러닝 기록'));
  assert.ok(html.indexOf('현재 Human State') < html.indexOf('주간 활동 근거'));
  assert.ok(html.indexOf('Encounter Insight') < html.indexOf('주간 활동 근거'));
});

test('dashboard keeps basic HTML structure stable', () => {
  const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
  const paragraphOpenCount = (html.match(/<p\b/gi) || []).length;
  const paragraphCloseCount = (html.match(/<\/p>/gi) || []).length;
  const ids = [...html.matchAll(/id="([^"]+)"/g)].map((match) => match[1]);
  const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index);

  assert.equal(paragraphOpenCount, paragraphCloseCount);
  assert.deepEqual([...new Set(duplicateIds)], []);
});

test('dashboard viewport smoke script is registered', () => {
  const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
  const smokeScript = readFileSync(new URL('../scripts/smoke_dashboard_viewport.mjs', import.meta.url), 'utf8');

  assert.equal(packageJson.scripts['smoke:dashboard:viewport'], 'node scripts/smoke_dashboard_viewport.mjs');
  assert.match(smokeScript, /PGHD Review Brief/);
  assert.match(smokeScript, /desktop/);
  assert.match(smokeScript, /mobile/);
  assert.match(smokeScript, /--screenshot=/);
  assert.match(smokeScript, /removeWithRetry/);
});
