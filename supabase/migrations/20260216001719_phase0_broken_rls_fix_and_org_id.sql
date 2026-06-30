-- Phase 0-1: Fix BROKEN RLS on unified_therapist_proposals
DROP POLICY IF EXISTS "Therapists can manage their own proposals" ON unified_therapist_proposals;
CREATE POLICY "Therapists can manage their own proposals" ON unified_therapist_proposals
  FOR ALL USING (
    therapist_id = (SELECT id FROM persons WHERE auth_user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Patients can view proposals for their requests" ON unified_therapist_proposals;
CREATE POLICY "Patients can view proposals for their requests" ON unified_therapist_proposals
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM unified_patient_requests r
      WHERE r.id = unified_therapist_proposals.request_id
        AND r.requester_person_id = (SELECT id FROM persons WHERE auth_user_id = auth.uid())
    )
  );

-- Phase 0-2: Marketplace tables add organization_id
ALTER TABLE matching_requests ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE unified_patient_requests ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE unified_therapist_proposals ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE unified_appointments ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);

-- Phase 0-3: Feature/PGHD/Device tables add organization_id
ALTER TABLE feature_flag_logs ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE feature_flag_overrides ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE user_device_tokens ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE pghd_oauth_sessions ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE person_events ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);

-- Phase 0-4: Payment tables add organization_id
ALTER TABLE payment_history ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE payment_refunds ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);
ALTER TABLE payment_events ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id);

-- Phase 0-5: RLS policies for new org_id columns
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'matching_requests') THEN
    EXECUTE 'CREATE POLICY org_member_access ON matching_requests FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'unified_patient_requests') THEN
    EXECUTE 'CREATE POLICY org_member_access ON unified_patient_requests FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'unified_therapist_proposals') THEN
    EXECUTE 'CREATE POLICY org_member_access ON unified_therapist_proposals FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'unified_appointments') THEN
    EXECUTE 'CREATE POLICY org_member_access ON unified_appointments FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'feature_flag_logs') THEN
    EXECUTE 'CREATE POLICY org_member_access ON feature_flag_logs FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'feature_flag_overrides') THEN
    EXECUTE 'CREATE POLICY org_member_access ON feature_flag_overrides FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'user_device_tokens') THEN
    EXECUTE 'CREATE POLICY org_member_access ON user_device_tokens FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'pghd_oauth_sessions') THEN
    EXECUTE 'CREATE POLICY org_member_access ON pghd_oauth_sessions FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'person_events') THEN
    EXECUTE 'CREATE POLICY org_member_access ON person_events FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'payment_history') THEN
    EXECUTE 'CREATE POLICY org_member_access ON payment_history FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'payment_refunds') THEN
    EXECUTE 'CREATE POLICY org_member_access ON payment_refunds FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'payment_events') THEN
    EXECUTE 'CREATE POLICY org_member_access ON payment_events FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
END $$;;
