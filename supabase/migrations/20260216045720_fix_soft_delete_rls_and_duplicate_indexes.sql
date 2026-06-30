-- 1. Soft delete: encounters (deleted_at IS NULL filter on all SELECT policies)
DROP POLICY IF EXISTS "encounters_admin_access" ON encounters;
CREATE POLICY "encounters_admin_access" ON encounters FOR SELECT USING (deleted_at IS NULL AND EXISTS (SELECT 1 FROM organization_members WHERE person_id = get_my_person_id() AND role IN ('owner', 'admin') AND organization_id = encounters.organization_id AND status = 'active'));

DROP POLICY IF EXISTS "encounters_patient_access" ON encounters;
CREATE POLICY "encounters_patient_access" ON encounters FOR SELECT USING (deleted_at IS NULL AND subject_person_id = get_my_person_id());

DROP POLICY IF EXISTS "encounters_provider_access" ON encounters;
CREATE POLICY "encounters_provider_access" ON encounters FOR SELECT USING (deleted_at IS NULL AND EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounters.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'));

-- 2. Soft delete: encounter_media
DROP POLICY IF EXISTS "encounter_media_org_read" ON encounter_media;
CREATE POLICY "encounter_media_org_read" ON encounter_media FOR SELECT USING (deleted_at IS NULL AND EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounter_media.organization_id AND om.status = 'active'));

DROP POLICY IF EXISTS "encounter_media_patient_read" ON encounter_media;
CREATE POLICY "encounter_media_patient_read" ON encounter_media FOR SELECT USING (deleted_at IS NULL AND subject_person_id = get_my_person_id());

-- 3. Soft delete: invoices
DROP POLICY IF EXISTS "invoices_select" ON invoices;
CREATE POLICY "invoices_select" ON invoices FOR SELECT USING (deleted_at IS NULL AND EXISTS (SELECT 1 FROM organization_members om WHERE om.organization_id = invoices.organization_id AND om.person_id = get_my_person_id()));

-- 4. Soft delete: leads
DROP POLICY IF EXISTS "leads_org_read" ON leads;
CREATE POLICY "leads_org_read" ON leads FOR SELECT USING (deleted_at IS NULL AND EXISTS (SELECT 1 FROM organization_members om WHERE om.organization_id = leads.organization_id AND om.person_id = get_my_person_id() AND om.role IN ('owner', 'admin', 'provider', 'staff')));;
