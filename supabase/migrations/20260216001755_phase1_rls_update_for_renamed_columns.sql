-- Fix RLS that referenced therapist_id (now provider_person_id)
DROP POLICY IF EXISTS "Therapists can manage their own proposals" ON unified_therapist_proposals;
CREATE POLICY "Providers can manage their own proposals" ON unified_therapist_proposals
  FOR ALL USING (
    provider_person_id = (SELECT id FROM persons WHERE auth_user_id = auth.uid())
  );;
