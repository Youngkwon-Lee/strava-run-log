-- 1. MV: also revoke from authenticated (advisor checks both anon AND authenticated)
REVOKE ALL ON mv_organization_stats FROM authenticated;
REVOKE ALL ON mv_patient_dashboard_summary FROM authenticated;
REVOKE ALL ON professional_profiles FROM authenticated;
-- Grant back SELECT only to authenticated for professional_profiles (public directory)
GRANT SELECT ON professional_profiles TO authenticated;

-- 2. booking_events INSERT: restrict to booking participants
DROP POLICY IF EXISTS "booking_events_insert" ON booking_events;
CREATE POLICY "booking_events_insert" ON booking_events FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.id = booking_events.booking_id
    AND (b.subject_person_id = get_my_person_id() OR b.provider_person_id = get_my_person_id())
  )
  OR is_org_member(organization_id)
);

-- 3. clinical_events INSERT: restrict to org members (audit trail)
DROP POLICY IF EXISTS "clinical_events_insert" ON clinical_events;
CREATE POLICY "clinical_events_insert" ON clinical_events FOR INSERT WITH CHECK (
  is_org_member(organization_id)
);

-- 4. cron_execution_logs INSERT: service_role only
DROP POLICY IF EXISTS "service_role_insert_cron_logs" ON cron_execution_logs;
CREATE POLICY "service_role_insert_cron_logs" ON cron_execution_logs FOR INSERT TO service_role WITH CHECK (true);;
