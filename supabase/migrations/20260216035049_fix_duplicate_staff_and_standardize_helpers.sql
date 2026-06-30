-- Fix 6 policies with duplicate 'staff' in role arrays + standardize to get_my_person_id()

-- allergy_intolerances
DROP POLICY IF EXISTS "allergy_member_select" ON allergy_intolerances;
CREATE POLICY "allergy_member_select" ON allergy_intolerances FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = allergy_intolerances.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff')));

-- assessment_form_responses
DROP POLICY IF EXISTS "afr_member_select" ON assessment_form_responses;
CREATE POLICY "afr_member_select" ON assessment_form_responses FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = assessment_form_responses.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff')));

-- booking_events
DROP POLICY IF EXISTS "booking_events_org_staff_select" ON booking_events;
CREATE POLICY "booking_events_org_staff_select" ON booking_events FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = booking_events.organization_id AND om.role IN ('owner', 'admin', 'provider', 'staff')));

-- bookings
DROP POLICY IF EXISTS "bookings_org_staff_select" ON bookings;
CREATE POLICY "bookings_org_staff_select" ON bookings FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = bookings.organization_id AND om.role IN ('provider', 'staff')));

-- org_patients (already uses get_my_person_id, just fix dup staff)
DROP POLICY IF EXISTS "org_patients_staff_view" ON org_patients;
CREATE POLICY "org_patients_staff_view" ON org_patients FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members m WHERE m.organization_id = org_patients.organization_id AND m.person_id = get_my_person_id() AND m.role IN ('owner', 'admin', 'provider', 'staff') AND m.status = 'active' AND m.deleted_at IS NULL));

-- person_events
DROP POLICY IF EXISTS "person_events_read_own_or_org" ON person_events;
CREATE POLICY "person_events_read_own_or_org" ON person_events FOR SELECT USING (person_id = get_my_person_id() OR EXISTS (SELECT 1 FROM organization_members om1 WHERE om1.person_id = get_my_person_id() AND om1.organization_id IN (SELECT om2.organization_id FROM organization_members om2 WHERE om2.person_id = person_events.person_id) AND om1.role IN ('owner', 'admin', 'provider', 'staff')));;
