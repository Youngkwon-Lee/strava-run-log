-- 1. subscription_usage: org member can read, org admin can write
CREATE POLICY "org_members_read_usage" ON subscription_usage
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM subscriptions s
      WHERE s.id = subscription_usage.subscription_id
        AND is_org_member(s.organization_id)
    )
  );

CREATE POLICY "org_admins_manage_usage" ON subscription_usage
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM subscriptions s
      WHERE s.id = subscription_usage.subscription_id
        AND is_org_admin(s.organization_id)
    )
  );

CREATE POLICY "service_role_full_access_usage" ON subscription_usage
  FOR ALL TO service_role USING (true);

-- 2. marketplace_requests_private: only request owner can see own private data
CREATE POLICY "owner_read_own_private" ON marketplace_requests_private
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM marketplace_requests mr
      WHERE mr.id = marketplace_requests_private.request_id
        AND mr.requester_person_id = get_my_person_id()
    )
  );

CREATE POLICY "owner_insert_own_private" ON marketplace_requests_private
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM marketplace_requests mr
      WHERE mr.id = marketplace_requests_private.request_id
        AND mr.requester_person_id = get_my_person_id()
    )
  );

CREATE POLICY "org_admin_read_private" ON marketplace_requests_private
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM marketplace_requests mr
      WHERE mr.id = marketplace_requests_private.request_id
        AND is_org_admin(mr.organization_id)
    )
  );

CREATE POLICY "service_role_full_access_private" ON marketplace_requests_private
  FOR ALL TO service_role USING (true);

-- 3. Fix role constraint mismatch: align organization_invites with organization_members
ALTER TABLE organization_invites DROP CONSTRAINT IF EXISTS organization_invites_role_check;
ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_role_check
  CHECK (role::text = ANY(ARRAY['owner','admin','clinician','trainer','staff','assistant','viewer','patient','member']));;
