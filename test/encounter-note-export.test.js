import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildEncounterNoteExport } from '../lib/encounter-note-export.js';

test('buildEncounterNoteExport creates an encounter_notes draft export row', () => {
  const draft = buildEncounterNoteExport({
    encounterId: '11111111-1111-4111-8111-111111111111',
    organizationId: '22222222-2222-4222-8222-222222222222',
    subjectPersonId: '33333333-3333-4333-8333-333333333333',
    providerPersonId: '44444444-4444-4444-8444-444444444444',
    noteFormat: 'wellness_note',
    insight: {
      insightType: 'load_review',
      severity: 'alert',
      title: 'Review recent load',
      noteDraft: 'PGHD review: Review recent load',
      evidence: ['fatigue 80%'],
      sourceActivities: [{
        runLogRunId: '55555555-5555-4555-8555-555555555555',
        pghdActivityEventId: '66666666-6666-4666-8666-666666666666',
        name: 'Morning rehab run',
        distanceKm: 4.02
      }]
    },
    generatedAt: '2026-06-22T00:00:00Z'
  });

  assert.equal(draft.table, 'encounter_notes');
  assert.deepEqual(draft.upsertKey, ['encounter_id', 'note_format']);
  assert.equal(draft.handoff.targetApp, 'physio_app');
  assert.equal(draft.handoff.targetRepository, 'createNoteRepository');
  assert.equal(draft.handoff.targetMethod, 'upsert');
  assert.equal(draft.handoff.conflictTarget, 'encounter_id,note_format');
  assert.equal(draft.row.status, 'draft');
  assert.equal(draft.row.requires_approval, true);
  assert.equal(draft.row.note_content, 'PGHD review: Review recent load');
  assert.equal(draft.row.data, undefined);
  assert.equal(draft.row.source_system, 'strava_run_log_pghd');
  assert.equal(draft.row.source_type, 'pghd_encounter_insight');
  assert.equal(draft.row.ai_draft_snapshot.pghd_insight.insightType, 'load_review');
  assert.equal(
    draft.row.ai_draft_snapshot.pghd_insight.sourceActivities[0].pghdActivityEventId,
    '66666666-6666-4666-8666-666666666666'
  );
  assert.equal(draft.row.discipline_sections.pghd_note_draft.review_state, 'draft_exported');
  assert.equal(draft.repositoryParams.note_content, 'PGHD review: Review recent load');
  assert.equal(draft.repositoryParams.discipline_sections.pghd_note_draft.source_system, 'strava_run_log_pghd');
  assert.equal(draft.repositoryParams.source_system, 'strava_run_log_pghd');
  assert.equal(draft.repositoryParams.source_type, 'pghd_encounter_insight');
  assert.equal(draft.repositoryParams.ai_draft_snapshot.review_state, 'draft_exported');
});

test('buildEncounterNoteExport requires reviewed note content', () => {
  assert.throws(
    () => buildEncounterNoteExport({ insight: { title: 'No draft' } }),
    /note content is required/
  );
});
