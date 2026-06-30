-- ============================================================
-- Rename legacy columns in encounter_notes, bookings, recurring_booking_templates
-- Scope: 6 column renames, 6 index recreations, 9 RLS policy updates, 3 function updates, 1 broken function drop
-- ============================================================

-- PART 1: Column Renames
ALTER TABLE encounter_notes RENAME COLUMN expert_id TO provider_person_id;
ALTER TABLE encounter_notes RENAME COLUMN person_id TO subject_person_id;
ALTER TABLE bookings RENAME COLUMN professional_id TO provider_person_id;
ALTER TABLE bookings RENAME COLUMN person_id TO subject_person_id;
ALTER TABLE recurring_booking_templates RENAME COLUMN professional_id TO provider_person_id;
ALTER TABLE recurring_booking_templates RENAME COLUMN person_id TO subject_person_id;

-- PART 2: Index Recreation
DROP INDEX IF EXISTS idx_encounter_notes_expert;
CREATE INDEX idx_encounter_notes_provider ON encounter_notes (provider_person_id);
DROP INDEX IF EXISTS idx_encounter_notes_person;
CREATE INDEX idx_encounter_notes_subject ON encounter_notes (subject_person_id);
DROP INDEX IF EXISTS idx_bookings_professional_id;
CREATE INDEX idx_bookings_provider_person ON bookings (provider_person_id);
DROP INDEX IF EXISTS idx_bookings_person_id;
CREATE INDEX idx_bookings_subject_person ON bookings (subject_person_id);
DROP INDEX IF EXISTS idx_recurring_templates_professional;
CREATE INDEX idx_recurring_templates_provider ON recurring_booking_templates (provider_person_id) WHERE (is_active = true);

-- PART 3: RLS - encounter_notes
DROP POLICY IF EXISTS "encounter_notes_author_delete" ON encounter_notes;
CREATE POLICY "encounter_notes_author_delete" ON encounter_notes FOR DELETE USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.person_id = encounter_notes.provider_person_id AND om.organization_id = encounter_notes.organization_id AND om.status = 'active') AND status = 'draft');

DROP POLICY IF EXISTS "encounter_notes_author_update" ON encounter_notes;
CREATE POLICY "encounter_notes_author_update" ON encounter_notes FOR UPDATE USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.person_id = encounter_notes.provider_person_id AND om.organization_id = encounter_notes.organization_id AND om.status = 'active') AND status = 'draft');

DROP POLICY IF EXISTS "encounter_notes_org_insert" ON encounter_notes;
CREATE POLICY "encounter_notes_org_insert" ON encounter_notes FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounter_notes.organization_id AND om.status = 'active' AND om.role IN ('owner', 'admin', 'provider')));

DROP POLICY IF EXISTS "encounter_notes_org_read" ON encounter_notes;
CREATE POLICY "encounter_notes_org_read" ON encounter_notes FOR SELECT USING (EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounter_notes.organization_id AND om.status = 'active' AND om.role IN ('owner', 'admin', 'provider', 'staff')));

-- PART 4: RLS - bookings
DROP POLICY IF EXISTS "bookings_person_insert" ON bookings;
CREATE POLICY "bookings_subject_insert" ON bookings FOR INSERT WITH CHECK (subject_person_id = (SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid() LIMIT 1));

DROP POLICY IF EXISTS "bookings_person_select" ON bookings;
CREATE POLICY "bookings_subject_select" ON bookings FOR SELECT USING (subject_person_id = (SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid() LIMIT 1));

DROP POLICY IF EXISTS "bookings_person_update" ON bookings;
CREATE POLICY "bookings_subject_update" ON bookings FOR UPDATE USING (subject_person_id = (SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid() LIMIT 1) AND status IN ('pending', 'confirmed')) WITH CHECK (subject_person_id = (SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid() LIMIT 1));

DROP POLICY IF EXISTS "bookings_professional_select" ON bookings;
CREATE POLICY "bookings_provider_select" ON bookings FOR SELECT USING (provider_person_id = (SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid() LIMIT 1));

DROP POLICY IF EXISTS "bookings_professional_update" ON bookings;
CREATE POLICY "bookings_provider_update" ON bookings FOR UPDATE USING (provider_person_id = (SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid() LIMIT 1)) WITH CHECK (provider_person_id = (SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid() LIMIT 1));

-- PART 6: Drop broken function (references non-existent care_sessions table)
DROP FUNCTION IF EXISTS create_care_session_on_booking_confirmation();

-- PART 7: FK constraint rename
ALTER TABLE encounter_notes RENAME CONSTRAINT encounter_notes_expert_id_fkey TO encounter_notes_provider_person_id_fkey;
ALTER TABLE encounter_notes RENAME CONSTRAINT encounter_notes_person_id_fkey TO encounter_notes_subject_person_id_fkey;;
