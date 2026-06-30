
-- Phase 3: Consolidate 5 flag tables → 1 unified flag_definitions
-- red_flags(30) + yellow_flags(15) + orange_flags(8) + blue_flags(10) + black_flags(8) = 71 rows

CREATE TABLE flag_definitions (
  id SERIAL PRIMARY KEY,
  flag_type VARCHAR(10) NOT NULL CHECK (flag_type IN ('red', 'yellow', 'orange', 'blue', 'black')),
  flag_code VARCHAR(100),
  flag_name VARCHAR(255) NOT NULL,
  flag_name_ko VARCHAR(255),
  category VARCHAR(100),
  category_ko VARCHAR(255),
  description TEXT,
  description_ko TEXT,
  body_region VARCHAR(100),
  icd10_codes TEXT[],
  signs_symptoms JSONB DEFAULT '{}',
  screening_questions JSONB DEFAULT '{}',
  management_strategies JSONB DEFAULT '{}',
  assessment_tools TEXT[],
  urgency VARCHAR(50),
  risk_level VARCHAR(50),
  severity_score INTEGER,
  evidence_basis TEXT,
  type_specific_data JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_flag_definitions_type ON flag_definitions(flag_type);
CREATE INDEX idx_flag_definitions_category ON flag_definitions(category);
CREATE INDEX idx_flag_definitions_active ON flag_definitions(is_active) WHERE is_active = true;

COMMENT ON TABLE flag_definitions IS 'Unified clinical flag definitions (red/yellow/orange/blue/black). Consolidates 5 legacy tables.';
COMMENT ON COLUMN flag_definitions.type_specific_data IS 'Type-specific fields: red(differential_diagnosis, typical_presentation, action_required), yellow(chronicity_risk_multiplier, intervention_strategies), orange(referral_criteria, requires_psychiatric_referral), blue(workplace_factors, rtw_impact, requires_occupational_health), black(identification_questions, stakeholders, requires_external_coordination)';

-- Migrate red_flags (30 rows)
INSERT INTO flag_definitions (flag_type, flag_code, flag_name, flag_name_ko, category, category_ko, description, body_region, icd10_codes, signs_symptoms, urgency, severity_score, evidence_basis, type_specific_data)
SELECT
  'red',
  'RED_' || id,
  condition_name,
  condition_name_korean,
  category,
  category_korean,
  notes,
  body_region,
  icd10_codes,
  COALESCE(signs_symptoms, '{}'),
  urgency,
  severity_score,
  evidence_source,
  jsonb_build_object(
    'typical_presentation', typical_presentation,
    'action_required', action_required,
    'action_required_korean', action_required_korean,
    'differential_diagnosis', differential_diagnosis,
    'clinical_context', clinical_context,
    'data_source', data_source
  )
FROM red_flags;

-- Migrate yellow_flags (15 rows)
INSERT INTO flag_definitions (flag_type, flag_code, flag_name, flag_name_ko, category, description, description_ko, screening_questions, management_strategies, assessment_tools, risk_level, evidence_basis, is_active, type_specific_data)
SELECT
  'yellow',
  flag_code,
  flag_name,
  flag_name_ko,
  category,
  description,
  description_ko,
  COALESCE(screening_questions, '{}'),
  COALESCE(intervention_strategies, '{}'),
  assessment_tools,
  risk_level,
  evidence_basis,
  is_active,
  jsonb_build_object('chronicity_risk_multiplier', chronicity_risk_multiplier)
FROM yellow_flags;

-- Migrate orange_flags (8 rows)
INSERT INTO flag_definitions (flag_type, flag_code, flag_name, flag_name_ko, category, description, description_ko, screening_questions, management_strategies, evidence_basis, is_active, type_specific_data)
SELECT
  'orange',
  flag_code,
  flag_name,
  flag_name_ko,
  category,
  description,
  description_ko,
  COALESCE(screening_questions, '{}'),
  COALESCE(management_strategies, '{}'),
  evidence_basis,
  is_active,
  jsonb_build_object(
    'referral_criteria', referral_criteria,
    'severity_level', severity_level,
    'requires_psychiatric_referral', requires_psychiatric_referral
  )
FROM orange_flags;

-- Migrate blue_flags (10 rows)
INSERT INTO flag_definitions (flag_type, flag_code, flag_name, flag_name_ko, category, description, description_ko, screening_questions, management_strategies, evidence_basis, is_active, type_specific_data)
SELECT
  'blue',
  flag_code,
  flag_name,
  flag_name_ko,
  category,
  description,
  description_ko,
  COALESCE(screening_questions, '{}'),
  COALESCE(intervention_strategies, '{}'),
  evidence_basis,
  is_active,
  jsonb_build_object(
    'workplace_factors', workplace_factors,
    'rtw_impact', rtw_impact,
    'requires_occupational_health', requires_occupational_health
  )
FROM blue_flags;

-- Migrate black_flags (8 rows)
INSERT INTO flag_definitions (flag_type, flag_code, flag_name, flag_name_ko, category, description, description_ko, screening_questions, management_strategies, evidence_basis, is_active, type_specific_data)
SELECT
  'black',
  flag_code,
  flag_name,
  flag_name_ko,
  category,
  description,
  description_ko,
  COALESCE(identification_questions, '{}'),
  COALESCE(management_strategies, '{}'),
  evidence_basis,
  is_active,
  jsonb_build_object(
    'stakeholders', stakeholders,
    'recovery_impact', recovery_impact,
    'requires_external_coordination', requires_external_coordination
  )
FROM black_flags;

-- Enable RLS
ALTER TABLE flag_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "flag_definitions_read_all" ON flag_definitions FOR SELECT USING (true);

-- DROP old tables (no FK, no code refs)
DROP TABLE red_flags;
DROP TABLE yellow_flags;
DROP TABLE orange_flags;
DROP TABLE blue_flags;
DROP TABLE black_flags;
;
