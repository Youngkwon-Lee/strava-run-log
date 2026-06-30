-- Phase 5-1: Approach link
ALTER TABLE treatment_approaches ADD COLUMN IF NOT EXISTS approach_key text REFERENCES approach_registry(key);
ALTER TABLE encounters ADD COLUMN IF NOT EXISTS approach_keys text[] DEFAULT '{}';

-- Phase 5-2: Provenance table
CREATE TABLE IF NOT EXISTS data_provenance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_table text NOT NULL,
  source_id uuid NOT NULL,
  actor_person_id uuid REFERENCES persons(id),
  actor_type text NOT NULL DEFAULT 'human',
  organization_id uuid REFERENCES organizations(id),
  source_system text,
  device_info jsonb,
  method text NOT NULL,
  ai_model_id text,
  ai_confidence numeric,
  quality_tier text DEFAULT 'standard',
  verified_by uuid REFERENCES persons(id),
  verified_at timestamptz,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_provenance_source ON data_provenance(source_table, source_id);
CREATE INDEX IF NOT EXISTS idx_provenance_actor ON data_provenance(actor_person_id);
ALTER TABLE data_provenance ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'data_provenance') THEN
    EXECUTE 'CREATE POLICY org_member_access ON data_provenance FOR ALL USING (organization_id IS NULL OR is_org_member(organization_id))';
  END IF;
END $$;

-- Phase 5-3: encounters/encounter_notes provenance fields
ALTER TABLE encounters ADD COLUMN IF NOT EXISTS source_system text;
ALTER TABLE encounter_notes ADD COLUMN IF NOT EXISTS source_type text DEFAULT 'manual';
ALTER TABLE encounter_notes ADD COLUMN IF NOT EXISTS source_system text;;
