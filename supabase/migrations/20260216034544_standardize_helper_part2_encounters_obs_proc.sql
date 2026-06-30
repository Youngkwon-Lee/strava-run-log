-- Part 2: encounters, note_citations, observations, procedures

DROP POLICY IF EXISTS "encounters_admin_access" ON encounters;
CREATE POLICY "encounters_admin_access" ON encounters FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members WHERE person_id = get_my_person_id() AND role IN ('owner', 'admin') AND organization_id = encounters.organization_id AND status = 'active'));

DROP POLICY IF EXISTS "encounters_insert_by_member" ON encounters;
CREATE POLICY "encounters_insert_by_member" ON encounters FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounters.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'));

DROP POLICY IF EXISTS "encounters_patient_access" ON encounters;
CREATE POLICY "encounters_patient_access" ON encounters FOR SELECT USING (subject_person_id = get_my_person_id());

DROP POLICY IF EXISTS "encounters_therapist_access" ON encounters;
CREATE POLICY "encounters_provider_access" ON encounters FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounters.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'));

DROP POLICY IF EXISTS "note_citations_delete" ON note_citations;
CREATE POLICY "note_citations_delete" ON note_citations FOR DELETE USING (EXISTS (SELECT 1 FROM encounter_notes en JOIN encounters e ON e.id = en.encounter_id JOIN organization_members om ON om.organization_id = e.organization_id WHERE en.id = note_citations.encounter_note_id AND om.person_id = get_my_person_id() AND om.status = 'active'));

DROP POLICY IF EXISTS "note_citations_insert" ON note_citations;
CREATE POLICY "note_citations_insert" ON note_citations FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM encounter_notes en JOIN encounters e ON e.id = en.encounter_id JOIN organization_members om ON om.organization_id = e.organization_id WHERE en.id = note_citations.encounter_note_id AND om.person_id = get_my_person_id() AND om.status = 'active'));

DROP POLICY IF EXISTS "note_citations_view" ON note_citations;
CREATE POLICY "note_citations_view" ON note_citations FOR SELECT USING (EXISTS (SELECT 1 FROM encounter_notes en JOIN encounters e ON e.id = en.encounter_id WHERE en.id = note_citations.encounter_note_id AND (e.subject_person_id = get_my_person_id() OR EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = e.organization_id AND om.status = 'active'))));

DROP POLICY IF EXISTS "observations_admin_access" ON observations;
CREATE POLICY "observations_admin_access" ON observations FOR ALL USING (EXISTS (SELECT 1 FROM organization_members WHERE person_id = get_my_person_id() AND role IN ('owner', 'admin') AND organization_id = observations.organization_id));

DROP POLICY IF EXISTS "observations_patient_access" ON observations;
CREATE POLICY "observations_patient_access" ON observations FOR SELECT USING (subject_person_id = get_my_person_id());

DROP POLICY IF EXISTS "observations_therapist_access" ON observations;
CREATE POLICY "observations_provider_access" ON observations FOR SELECT USING (EXISTS (SELECT 1 FROM encounters e JOIN organization_members om ON om.organization_id = e.organization_id WHERE e.id = observations.encounter_id AND om.person_id = get_my_person_id() AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'));

DROP POLICY IF EXISTS "procedures_admin_access" ON procedures;
CREATE POLICY "procedures_admin_access" ON procedures FOR ALL USING (EXISTS (SELECT 1 FROM organization_members WHERE person_id = get_my_person_id() AND role IN ('owner', 'admin') AND organization_id = procedures.organization_id));

DROP POLICY IF EXISTS "procedures_patient_access" ON procedures;
CREATE POLICY "procedures_patient_access" ON procedures FOR SELECT USING (subject_person_id = get_my_person_id());

DROP POLICY IF EXISTS "procedures_therapist_access" ON procedures;
CREATE POLICY "procedures_provider_access" ON procedures FOR SELECT USING (EXISTS (SELECT 1 FROM encounters e JOIN organization_members om ON om.organization_id = e.organization_id WHERE e.id = procedures.encounter_id AND om.person_id = get_my_person_id() AND om.role IN ('owner', 'admin', 'provider', 'staff') AND om.status = 'active'));;
