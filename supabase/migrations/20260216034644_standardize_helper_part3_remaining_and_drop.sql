-- Part 3: practitioner_roles, service_requests, smart_*, then DROP my_person_id()

DROP POLICY IF EXISTS "practitioner_roles_own_access" ON practitioner_roles;
CREATE POLICY "practitioner_roles_own_access" ON practitioner_roles FOR ALL USING (practitioner_id = get_my_person_id());

DROP POLICY IF EXISTS "service_requests_patient_access" ON service_requests;
CREATE POLICY "service_requests_patient_access" ON service_requests FOR ALL USING (subject_person_id = get_my_person_id());

DROP POLICY IF EXISTS "service_requests_requester_access" ON service_requests;
CREATE POLICY "service_requests_requester_access" ON service_requests FOR ALL USING (requester_id = get_my_person_id() OR performer_id = get_my_person_id());

DROP POLICY IF EXISTS "smart_audit_user_read" ON smart_audit_log;
CREATE POLICY "smart_audit_user_read" ON smart_audit_log FOR SELECT USING (practitioner_person_id = get_my_person_id());

DROP POLICY IF EXISTS "smart_tokens_user_read" ON smart_tokens;
CREATE POLICY "smart_tokens_user_read" ON smart_tokens FOR SELECT USING (practitioner_person_id = get_my_person_id());

DROP POLICY IF EXISTS "smart_tokens_user_revoke" ON smart_tokens;
CREATE POLICY "smart_tokens_user_revoke" ON smart_tokens FOR UPDATE USING (practitioner_person_id = get_my_person_id()) WITH CHECK (revoked = true AND revoked_at IS NOT NULL);

-- DROP the wrapper function (no longer needed)
DROP FUNCTION IF EXISTS my_person_id();;
