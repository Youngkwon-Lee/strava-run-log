-- Allow providers with an accepted match_result to read the client's self-assessments
-- This covers guest self-assessments (organization_id IS NULL, source_type='patient_self')
CREATE POLICY "afr_matched_provider_select"
  ON assessment_form_responses
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM match_results mr
      WHERE mr.client_person_id = assessment_form_responses.subject_person_id
        AND mr.provider_person_id = get_my_person_id()
        AND mr.status = 'accepted'
    )
  );
;
