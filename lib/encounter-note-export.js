function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function normalizeNoteText(value) {
  return String(value || '').replace(/\r\n/g, '\n').trim();
}

function insightSummary(insight = {}) {
  return compactObject({
    insightType: insight.insightType,
    severity: insight.severity,
    title: insight.title,
    summary: insight.summary,
    providerSource: insight.providerSource,
    confidence: insight.confidence,
    evidence: Array.isArray(insight.evidence) ? insight.evidence.slice(0, 10) : undefined,
    suggestedQuestions: Array.isArray(insight.suggestedQuestions) ? insight.suggestedQuestions.slice(0, 10) : undefined,
    suggestedActions: Array.isArray(insight.suggestedActions) ? insight.suggestedActions.slice(0, 10) : undefined,
    sourceSnapshots: Array.isArray(insight.sourceSnapshots) ? insight.sourceSnapshots.slice(0, 10) : undefined,
    sourceActivities: Array.isArray(insight.sourceActivities) ? insight.sourceActivities.slice(0, 10) : undefined
  });
}

export function buildEncounterNoteExport(input = {}) {
  const insight = input.insight && typeof input.insight === 'object' ? input.insight : {};
  const noteContent = normalizeNoteText(input.editedNoteContent || input.noteContent || insight.noteDraft);
  if (!noteContent) {
    throw new Error('note content is required');
  }

  const noteFormat = String(input.noteFormat || 'wellness_note').trim();
  const status = String(input.status || 'draft').trim();
  const provenance = compactObject({
    source_system: 'strava_run_log_pghd',
    source_type: 'pghd_encounter_insight',
    generated_at: input.generatedAt,
    review_state: 'draft_exported',
    pghd_insight: insightSummary(insight)
  });
  const disciplineSections = compactObject({
    pghd_note_draft: provenance
  });
  const row = compactObject({
    encounter_id: input.encounterId,
    organization_id: input.organizationId,
    subject_person_id: input.subjectPersonId,
    provider_person_id: input.providerPersonId,
    note_format: noteFormat,
    status,
    is_medical_context: input.isMedicalContext ?? false,
    requires_approval: input.requiresApproval ?? true,
    note_content: noteContent,
    source_system: 'strava_run_log_pghd',
    source_type: 'pghd_encounter_insight',
    ai_draft_snapshot: provenance,
    discipline_sections: disciplineSections
  });
  const repositoryParams = compactObject({
    encounter_id: row.encounter_id,
    organization_id: row.organization_id,
    subject_person_id: row.subject_person_id,
    provider_person_id: row.provider_person_id,
    note_format: row.note_format,
    status: row.status,
    is_medical_context: row.is_medical_context,
    requires_approval: row.requires_approval,
    note_content: row.note_content,
    discipline_sections: row.discipline_sections,
    source_system: row.source_system,
    source_type: row.source_type,
    ai_draft_snapshot: row.ai_draft_snapshot
  });

  return {
    table: 'encounter_notes',
    mode: 'draft_export',
    upsertKey: ['encounter_id', 'note_format'],
    handoff: {
      targetApp: 'physio_app',
      targetRepository: 'createNoteRepository',
      targetMethod: 'upsert',
      conflictTarget: 'encounter_id,note_format',
      persistVia: 'authenticated server route/action',
      reviewPolicy: 'keep status=draft until professional sign-off'
    },
    repositoryParams,
    row
  };
}
