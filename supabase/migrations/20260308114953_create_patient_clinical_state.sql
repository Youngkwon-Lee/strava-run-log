
-- Patient Clinical State Table
-- 목적: AI agent가 참조하는 Persistent Patient State (OAG 패턴)

-- 1. 테이블 생성
CREATE TABLE IF NOT EXISTS patient_clinical_state (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

  -- 4-domain state (JSONB — 스키마는 Zod에서 관리)
  state           JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Typed columns for queryability
  state_version   INTEGER NOT NULL DEFAULT 1,

  -- Trigger metadata
  trigger_event        TEXT,
  trigger_encounter_id UUID REFERENCES encounters(id) ON DELETE SET NULL,

  -- Timestamps
  computed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- UNIQUE constraint for UPSERT
  CONSTRAINT uq_patient_state_person_org UNIQUE (subject_person_id, organization_id)
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_patient_state_org
  ON patient_clinical_state(organization_id);
CREATE INDEX IF NOT EXISTS idx_patient_state_person
  ON patient_clinical_state(subject_person_id);
CREATE INDEX IF NOT EXISTS idx_patient_state_risk_level
  ON patient_clinical_state((state->'risk'->>'composite_level'));
CREATE INDEX IF NOT EXISTS idx_patient_state_updated
  ON patient_clinical_state(updated_at DESC);

-- 3. RLS Policies
ALTER TABLE patient_clinical_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "patient_state_select_org_member"
  ON patient_clinical_state FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "patient_state_insert_service"
  ON patient_clinical_state FOR INSERT
  WITH CHECK (true);

CREATE POLICY "patient_state_update_service"
  ON patient_clinical_state FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- 4. Updated_at trigger
CREATE OR REPLACE FUNCTION trg_patient_state_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_patient_clinical_state_updated
  BEFORE UPDATE ON patient_clinical_state
  FOR EACH ROW EXECUTE FUNCTION trg_patient_state_updated_at();

-- 5. Comments
COMMENT ON TABLE patient_clinical_state IS
  'Persistent patient clinical state (ICF-based 4-domain). Updated on encounter completion. Used as OAG input for all AI agents.';

COMMENT ON COLUMN patient_clinical_state.state IS
  'JSONB: { condition, impairment, function, risk } — schema managed by Zod (patient-state.schema.ts)';
;
