-- ============================================================
-- 1. encounter_media: Generic media/document table (FHIR Media + DocumentReference)
-- 2. medication_statements: FHIR MedicationStatement
-- 3. persons/organizations: fhir_id columns
-- ============================================================

-- ============================================================
-- PART 1: encounter_media
-- ============================================================

CREATE TABLE encounter_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fhir_id text UNIQUE,
  -- Classification
  media_type text NOT NULL,
  media_subtype text,
  -- Context
  subject_person_id uuid NOT NULL REFERENCES persons(id),
  organization_id uuid NOT NULL REFERENCES organizations(id),
  encounter_id uuid REFERENCES encounters(id),
  procedure_id uuid REFERENCES procedures(id),
  -- Storage
  storage_bucket text NOT NULL DEFAULT 'media',
  storage_path text NOT NULL,
  original_filename text,
  content_type text NOT NULL,
  file_size_bytes bigint,
  -- Media dimensions
  width integer,
  height integer,
  duration_seconds numeric,
  -- Content
  title text,
  description text,
  body_site_code text,
  laterality text,
  -- AI analysis
  analysis_status text DEFAULT 'pending',
  analysis_result jsonb,
  ai_model_id text,
  ai_confidence numeric,
  -- FHIR DocumentReference
  doc_status text DEFAULT 'current',
  doc_category text[] DEFAULT '{}',
  -- Metadata
  captured_at timestamptz,
  tags text[] DEFAULT '{}',
  metadata jsonb DEFAULT '{}',
  -- Audit
  created_by uuid NOT NULL REFERENCES persons(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT encounter_media_type_check CHECK (media_type IN ('photo', 'video', 'audio', 'document', 'attachment')),
  CONSTRAINT encounter_media_laterality_check CHECK (laterality IS NULL OR laterality IN ('left', 'right', 'bilateral')),
  CONSTRAINT encounter_media_analysis_check CHECK (analysis_status IN ('pending', 'processing', 'completed', 'failed', 'skipped')),
  CONSTRAINT encounter_media_doc_status_check CHECK (doc_status IN ('current', 'superseded', 'entered-in-error')),
  CONSTRAINT encounter_media_ai_confidence_check CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1))
);

ALTER TABLE encounter_media ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX idx_encounter_media_org_subject ON encounter_media (organization_id, subject_person_id, created_at DESC);
CREATE INDEX idx_encounter_media_encounter ON encounter_media (encounter_id) WHERE encounter_id IS NOT NULL;
CREATE INDEX idx_encounter_media_procedure ON encounter_media (procedure_id) WHERE procedure_id IS NOT NULL;
CREATE INDEX idx_encounter_media_type ON encounter_media (media_type, media_subtype);
CREATE INDEX idx_encounter_media_tags ON encounter_media USING gin (tags);
CREATE INDEX idx_encounter_media_analysis ON encounter_media (analysis_status) WHERE analysis_status IN ('pending', 'processing');
CREATE UNIQUE INDEX idx_encounter_media_storage ON encounter_media (storage_bucket, storage_path) WHERE deleted_at IS NULL;

-- RLS Policies
CREATE POLICY "encounter_media_org_read" ON encounter_media FOR SELECT USING (
  EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounter_media.organization_id AND om.status = 'active')
);

CREATE POLICY "encounter_media_provider_insert" ON encounter_media FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounter_media.organization_id AND om.status = 'active' AND om.role IN ('owner', 'admin', 'provider'))
);

CREATE POLICY "encounter_media_provider_update" ON encounter_media FOR UPDATE USING (
  EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounter_media.organization_id AND om.status = 'active' AND om.role IN ('owner', 'admin', 'provider'))
);

CREATE POLICY "encounter_media_admin_delete" ON encounter_media FOR DELETE USING (
  EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = encounter_media.organization_id AND om.status = 'active' AND om.role IN ('owner', 'admin'))
);

CREATE POLICY "encounter_media_patient_read" ON encounter_media FOR SELECT USING (
  subject_person_id = get_my_person_id()
);

COMMENT ON TABLE encounter_media IS 'FHIR Media + DocumentReference. 세션 중 촬영한 사진/동영상, 운동 시연 비디오, PDF 문서, 첨부파일 등 범용 미디어 저장소. posture_photos는 자세분석 전용(별도 유지).';

-- ============================================================
-- PART 2: medication_statements (FHIR MedicationStatement)
-- ============================================================

CREATE TABLE medication_statements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fhir_id text NOT NULL UNIQUE,
  status text NOT NULL,
  -- Medication
  medication_code text NOT NULL,
  medication_display text,
  medication_code_system text DEFAULT 'http://www.whocc.no/atc',
  -- Subject
  subject_person_id uuid NOT NULL REFERENCES persons(id),
  organization_id uuid NOT NULL REFERENCES organizations(id),
  encounter_id uuid REFERENCES encounters(id),
  -- Timing
  effective_start timestamptz,
  effective_end timestamptz,
  date_asserted timestamptz DEFAULT now(),
  -- Details
  dosage jsonb,
  reason_code text[],
  reason_reference_ids uuid[],
  note text,
  -- Source
  information_source_type text DEFAULT 'patient',
  information_source_person_id uuid REFERENCES persons(id),
  -- Audit
  created_by uuid NOT NULL REFERENCES persons(id),
  updated_by uuid REFERENCES persons(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT medication_statements_status_check CHECK (status IN ('active', 'completed', 'entered-in-error', 'intended', 'stopped', 'on-hold', 'unknown', 'not-taken')),
  CONSTRAINT medication_statements_source_check CHECK (information_source_type IN ('patient', 'practitioner', 'related-person', 'system'))
);

ALTER TABLE medication_statements ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_medication_statements_subject ON medication_statements (subject_person_id, status);
CREATE INDEX idx_medication_statements_org ON medication_statements (organization_id, subject_person_id);
CREATE INDEX idx_medication_statements_encounter ON medication_statements (encounter_id) WHERE encounter_id IS NOT NULL;
CREATE INDEX idx_medication_statements_medication ON medication_statements (medication_code) WHERE status = 'active';

CREATE POLICY "medication_statements_org_read" ON medication_statements FOR SELECT USING (
  EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = medication_statements.organization_id AND om.status = 'active')
);

CREATE POLICY "medication_statements_provider_write" ON medication_statements FOR ALL USING (
  EXISTS (SELECT 1 FROM organization_members om WHERE om.person_id = get_my_person_id() AND om.organization_id = medication_statements.organization_id AND om.status = 'active' AND om.role IN ('owner', 'admin', 'provider'))
);

CREATE POLICY "medication_statements_patient_read" ON medication_statements FOR SELECT USING (
  subject_person_id = get_my_person_id()
);

COMMENT ON TABLE medication_statements IS 'FHIR MedicationStatement. 환자의 현재/과거 복용 약물 기록. exercise_medication_interactions와 연계하여 운동 금기사항 자동 체크.';

-- ============================================================
-- PART 3: fhir_id on persons and organizations
-- ============================================================

ALTER TABLE persons ADD COLUMN IF NOT EXISTS fhir_id text;
CREATE UNIQUE INDEX IF NOT EXISTS persons_fhir_id_key ON persons (fhir_id) WHERE fhir_id IS NOT NULL;

ALTER TABLE organizations ADD COLUMN IF NOT EXISTS fhir_id text;
CREATE UNIQUE INDEX IF NOT EXISTS organizations_fhir_id_key ON organizations (fhir_id) WHERE fhir_id IS NOT NULL;

COMMENT ON COLUMN persons.fhir_id IS 'FHIR Patient/Practitioner resource ID';
COMMENT ON COLUMN organizations.fhir_id IS 'FHIR Organization resource ID';;
