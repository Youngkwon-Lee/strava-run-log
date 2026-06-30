-- 1. Drop duplicate UNIQUE constraint on pghd_connections
ALTER TABLE pghd_connections DROP CONSTRAINT IF EXISTS pghd_connections_person_provider_unique;

-- 2. Fix ops tables: replace PUBLIC USING(true) with service_role only
DROP POLICY IF EXISTS "service_role_only" ON api_idempotency;
CREATE POLICY "service_role_only" ON api_idempotency FOR ALL TO service_role USING (true);

DROP POLICY IF EXISTS "job_queue_service_only" ON job_queue;
CREATE POLICY "job_queue_service_only" ON job_queue FOR ALL TO service_role USING (true);

DROP POLICY IF EXISTS "request_log_service_only" ON request_log;
CREATE POLICY "request_log_service_only" ON request_log FOR ALL TO service_role USING (true);

DROP POLICY IF EXISTS "workflow_service_only" ON workflow_steps;
CREATE POLICY "workflow_service_only" ON workflow_steps FOR ALL TO service_role USING (true);

-- 3. Revoke anon SELECT from materialized views
REVOKE SELECT ON mv_organization_stats FROM anon;
REVOKE SELECT ON mv_patient_dashboard_summary FROM anon;
REVOKE SELECT ON professional_profiles FROM anon;

-- 4. Fix marketplace_appointments: replace overly permissive INSERT/UPDATE
DROP POLICY IF EXISTS "Users can insert appointments" ON marketplace_appointments;
CREATE POLICY "marketplace_appointments_insert" ON marketplace_appointments FOR INSERT WITH CHECK (
  subject_person_id = get_my_person_id() OR provider_person_id = get_my_person_id()
  OR (organization_id IS NOT NULL AND is_org_member(organization_id))
);

DROP POLICY IF EXISTS "Users can update their own appointments" ON marketplace_appointments;
CREATE POLICY "marketplace_appointments_update" ON marketplace_appointments FOR UPDATE USING (
  subject_person_id = get_my_person_id() OR provider_person_id = get_my_person_id()
  OR (organization_id IS NOT NULL AND is_org_member(organization_id))
);;
