
-- Step 1-1: Add columns to clinical_content_registry
ALTER TABLE clinical_content_registry
  ADD COLUMN IF NOT EXISTS applicable_expert_types TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS body_region TEXT,
  ADD COLUMN IF NOT EXISTS sport_category TEXT,
  ADD COLUMN IF NOT EXISTS content_tags TEXT[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_ccr_expert_types
  ON clinical_content_registry USING GIN (applicable_expert_types);
CREATE INDEX IF NOT EXISTS idx_ccr_body_region
  ON clinical_content_registry (content_type, body_region);

-- Step 1-2: patient_consent_records
CREATE TABLE IF NOT EXISTS patient_consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  person_id UUID NOT NULL REFERENCES persons(id),
  content_code TEXT NOT NULL,
  signed_at TIMESTAMPTZ,
  signed_content_snapshot JSONB,
  delivery_method TEXT CHECK (delivery_method IN ('in_app','email','sms','paper')),
  encounter_id UUID REFERENCES encounters(id),
  created_by UUID REFERENCES persons(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE patient_consent_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "consent_org_read" ON patient_consent_records
  FOR SELECT TO authenticated
  USING (is_org_member(organization_id));

CREATE POLICY "consent_staff_write" ON patient_consent_records
  FOR INSERT TO authenticated
  WITH CHECK (is_org_member(organization_id));

CREATE INDEX IF NOT EXISTS idx_consent_records_org
  ON patient_consent_records (organization_id, person_id);
CREATE INDEX IF NOT EXISTS idx_consent_records_code
  ON patient_consent_records (person_id, content_code);
;
