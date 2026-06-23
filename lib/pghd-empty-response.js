function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
}

function scopedIdentity(query = {}) {
  return compactObject({
    subjectPersonId: query.subject_person_id,
    orgClientProfileId: query.org_client_profile_id,
    organizationId: query.organization_id,
    userId: query.user_id,
    pghdConnectionId: query.pghd_connection_id,
    source: query.source
  });
}

const EMPTY_RESPONSE_DETAILS = {
  no_weekly_activity: {
    message: 'No weekly PGHD activity summaries matched the current client/source filters.',
    operatorHints: [
      'Confirm the subject_person_id belongs to the target client.',
      'Confirm provider ingest has created run_log_runs rows for this person.',
      'Confirm the weekly summary view includes the requested provider source and date window.'
    ]
  },
  no_timeline_records: {
    message: 'No PGHD timeline activity records matched the current client/source filters.',
    operatorHints: [
      'Confirm a PGHD connection is mapped to the subject person.',
      'Confirm provider ingest has completed for the requested source.',
      'If filtering by pghd_connection_id or user_id, retry with subject_person_id to isolate mapping issues.'
    ]
  },
  no_persisted_state_snapshots: {
    message: 'No persisted Human State snapshots matched the current client/source filters.',
    operatorHints: [
      'Run derive=weekly to preview state signals without persisted rows.',
      'Run POST /api/run-log/state-snapshots after applying the Human State snapshot migration.',
      'Confirm the source filter maps to provider_source on persisted state rows.'
    ]
  },
  no_derived_state_snapshots: {
    message: 'No derived Human State snapshots could be calculated from weekly PGHD activity summaries.',
    operatorHints: [
      'Confirm at least one weekly summary exists for the requested subject_person_id.',
      'Confirm weekly summaries contain run_count, total_km, and moving_time_sec.',
      'Widen the date window or remove the provider source filter to check for available activity.'
    ]
  }
};

export function buildEmptyResponse(reason, query) {
  const details = EMPTY_RESPONSE_DETAILS[reason] || {
    message: 'No PGHD records matched the current filters.',
    operatorHints: ['Confirm the client identity, provider source, and ingest status.']
  };

  return {
    emptyReason: reason,
    emptyMessage: details.message,
    operatorHints: details.operatorHints,
    emptyScope: scopedIdentity(query)
  };
}
