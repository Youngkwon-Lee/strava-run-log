-- Part 1: clinical_events, conditions, diagnostic_reports, encounter_intake_snapshots

DROP POLICY IF EXISTS "clinical_events_actor_read" ON clinical_events;
CREATE POLICY "clinical_events_actor_read" ON clinical_events FOR SELECT USING (actor_id = get_my_person_id());

DROP POLICY IF EXISTS "clinical_events_admin_read" ON clinical_events;
CREATE POLICY "clinical_events_admin_read" ON clinical_events FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members WHERE person_id = get_my_person_id() AND role IN ('owner', 'admin') AND organization_id = clinical_events.organization_id));

DROP POLICY IF EXISTS "conditions_patient_access" ON conditions;
CREATE POLICY "conditions_patient_access" ON conditions FOR SELECT USING (subject_person_id = get_my_person_id());

DROP POLICY IF EXISTS "conditions_therapist_access" ON conditions;
CREATE POLICY "conditions_provider_access" ON conditions FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = conditions.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'));

DROP POLICY IF EXISTS "diagnostic_reports_admin_access" ON diagnostic_reports;
CREATE POLICY "diagnostic_reports_admin_access" ON diagnostic_reports FOR ALL USING (EXISTS (SELECT 1 FROM organization_members WHERE person_id = get_my_person_id() AND role IN ('owner', 'admin') AND organization_id = diagnostic_reports.organization_id));

DROP POLICY IF EXISTS "diagnostic_reports_clinician_access" ON diagnostic_reports;
CREATE POLICY "diagnostic_reports_provider_access" ON diagnostic_reports FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = diagnostic_reports.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'));

DROP POLICY IF EXISTS "diagnostic_reports_patient_access" ON diagnostic_reports;
CREATE POLICY "diagnostic_reports_patient_access" ON diagnostic_reports FOR SELECT USING (subject_person_id = get_my_person_id());

DROP POLICY IF EXISTS "diagnostic_reports_therapist_access" ON diagnostic_reports;
CREATE POLICY "diagnostic_reports_performer_access" ON diagnostic_reports FOR ALL USING (performer_id = get_my_person_id() OR organization_id IN (SELECT om.organization_id FROM organization_members om WHERE om.person_id = get_my_person_id()));

DROP POLICY IF EXISTS "intake_snapshots_insert" ON encounter_intake_snapshots;
CREATE POLICY "intake_snapshots_insert" ON encounter_intake_snapshots FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM encounters e JOIN organization_members om ON om.organization_id = e.organization_id WHERE e.id = encounter_intake_snapshots.encounter_id AND om.person_id = get_my_person_id() AND om.role IN ('owner', 'admin', 'provider') AND om.status = 'active'));

DROP POLICY IF EXISTS "intake_snapshots_view" ON encounter_intake_snapshots;
CREATE POLICY "intake_snapshots_view" ON encounter_intake_snapshots FOR SELECT USING (EXISTS (SELECT 1 FROM encounters e WHERE e.id = encounter_intake_snapshots.encounter_id AND (e.subject_person_id = get_my_person_id() OR EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = e.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'))));;
