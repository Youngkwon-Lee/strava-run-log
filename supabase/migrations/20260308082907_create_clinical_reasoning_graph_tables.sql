
-- ============================================================
-- Clinical Reasoning Graph — 8 Tables + 2 ALTER
-- Phase 1: JOSPT LBP CPG Foundation
-- ============================================================

-- 1. impairments — 손상/결손 유형
CREATE TABLE impairments (
  id SERIAL PRIMARY KEY,
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  name_ko VARCHAR(200),
  category VARCHAR(50) NOT NULL CHECK (category IN (
    'rom_deficit', 'muscle_weakness', 'motor_control_deficit', 
    'endurance_deficit', 'balance_deficit', 'sensory_deficit', 'pain_sensitization'
  )),
  body_region VARCHAR(50) CHECK (body_region IN (
    'lumbar', 'cervical', 'shoulder', 'knee', 'hip', 'ankle', 'thoracic', 'global'
  )),
  icf_code VARCHAR(20),
  assessment_codes TEXT[] DEFAULT '{}',
  severity_thresholds JSONB,
  common_causes TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_impairments_category ON impairments(category);
CREATE INDEX idx_impairments_body_region ON impairments(body_region);

-- 2. movement_patterns — 운동 패턴
CREATE TABLE movement_patterns (
  id SERIAL PRIMARY KEY,
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  name_ko VARCHAR(200),
  category VARCHAR(50) NOT NULL CHECK (category IN (
    'intolerance', 'compensation', 'instability', 'dyskinesis', 'asymmetry', 'deconditioning'
  )),
  body_region VARCHAR(50) CHECK (body_region IN (
    'lumbar', 'cervical', 'shoulder', 'knee', 'hip', 'ankle', 'thoracic', 'global'
  )),
  related_impairment_ids INT[] DEFAULT '{}',
  observable_signs JSONB,
  contributing_factors TEXT[] DEFAULT '{}',
  associated_conditions TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_movement_patterns_category ON movement_patterns(category);
CREATE INDEX idx_movement_patterns_body_region ON movement_patterns(body_region);

-- 3. reasoning_frameworks — 임상 추론 프레임워크
CREATE TABLE reasoning_frameworks (
  id SERIAL PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  name_ko VARCHAR(200),
  category VARCHAR(50) NOT NULL CHECK (category IN (
    'biomechanical', 'motor_control', 'developmental', 'movement_impairment'
  )),
  applicable_regions TEXT[] NOT NULL DEFAULT '{}',
  applicable_domains TEXT[] NOT NULL DEFAULT '{clinical}',
  evidence_level VARCHAR(10) CHECK (evidence_level IN ('A', 'B', 'C', 'D')),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. clinical_classifications — 분류 카테고리
CREATE TABLE clinical_classifications (
  id SERIAL PRIMARY KEY,
  framework_id INT NOT NULL REFERENCES reasoning_frameworks(id) ON DELETE CASCADE,
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  name_ko VARCHAR(200),
  body_region VARCHAR(50) NOT NULL CHECK (body_region IN (
    'lumbar', 'cervical', 'shoulder', 'knee', 'hip', 'ankle', 'thoracic', 'global'
  )),
  description TEXT,
  description_ko TEXT,
  prevalence_pct NUMERIC(5,2),
  typical_presentation JSONB,
  differential_from TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_classifications_framework ON clinical_classifications(framework_id);
CREATE INDEX idx_classifications_body_region ON clinical_classifications(body_region);

-- 5. reasoning_chains — 추론 체인 (핵심)
CREATE TABLE reasoning_chains (
  id SERIAL PRIMARY KEY,
  classification_id INT NOT NULL REFERENCES clinical_classifications(id) ON DELETE CASCADE,
  impairment_ids INT[] DEFAULT '{}',
  movement_pattern_ids INT[] DEFAULT '{}',
  symptom_pattern VARCHAR(200),
  symptom_pattern_ko VARCHAR(200),
  intolerance_pattern VARCHAR(100) CHECK (intolerance_pattern IN (
    'flexion', 'extension', 'rotation', 'lateral', 'mixed', 'load', 'none'
  )),
  pathology_hypothesis VARCHAR(200),
  pathology_hypothesis_ko VARCHAR(200),
  movement_impairment VARCHAR(200),
  movement_impairment_ko VARCHAR(200),
  functional_limitation VARCHAR(200),
  intervention_strategy VARCHAR(200),
  intervention_strategy_ko VARCHAR(200),
  phase_progression JSONB,
  evidence_level VARCHAR(10) CHECK (evidence_level IN ('A', 'B', 'C', 'D')),
  cpg_reference VARCHAR(500),
  contraindications TEXT[] DEFAULT '{}',
  precautions TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_chains_classification ON reasoning_chains(classification_id);

-- 6. classification_indicators — 분류 판별 기준
CREATE TABLE classification_indicators (
  id SERIAL PRIMARY KEY,
  classification_id INT NOT NULL REFERENCES clinical_classifications(id) ON DELETE CASCADE,
  indicator_type VARCHAR(50) NOT NULL CHECK (indicator_type IN (
    'symptom', 'test_result', 'observation', 'rom_pattern', 'movement_pattern', 'questionnaire'
  )),
  indicator_code VARCHAR(100),
  indicator_description VARCHAR(500),
  indicator_description_ko VARCHAR(500),
  expected_value VARCHAR(200),
  weight NUMERIC(3,2) NOT NULL DEFAULT 1.00 CHECK (weight >= 0 AND weight <= 1),
  is_required BOOLEAN NOT NULL DEFAULT false,
  is_excluding BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_indicators_classification ON classification_indicators(classification_id);
CREATE INDEX idx_indicators_type ON classification_indicators(indicator_type);

-- 7. intervention_protocols — 분류별 중재 매핑
CREATE TABLE intervention_protocols (
  id SERIAL PRIMARY KEY,
  classification_id INT NOT NULL REFERENCES clinical_classifications(id) ON DELETE CASCADE,
  chain_id INT REFERENCES reasoning_chains(id) ON DELETE SET NULL,
  intervention_type VARCHAR(50) NOT NULL CHECK (intervention_type IN (
    'exercise', 'manual_therapy', 'education', 'modality', 'referral', 'psychosocial'
  )),
  priority_order INT NOT NULL DEFAULT 1,
  name VARCHAR(200) NOT NULL,
  name_ko VARCHAR(200),
  description TEXT,
  exercise_tags TEXT[] DEFAULT '{}',
  exercise_tier_min INT DEFAULT 1 CHECK (exercise_tier_min >= 1 AND exercise_tier_min <= 4),
  exercise_tier_max INT DEFAULT 4 CHECK (exercise_tier_max >= 1 AND exercise_tier_max <= 4),
  dosing_template JSONB,
  contraindications TEXT[] DEFAULT '{}',
  evidence_level VARCHAR(10) CHECK (evidence_level IN ('A', 'B', 'C', 'D')),
  cpg_reference VARCHAR(500),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_protocols_classification ON intervention_protocols(classification_id);
CREATE INDEX idx_protocols_chain ON intervention_protocols(chain_id);

-- 8. psychosocial_intervention_paths — 심리사회적 개입 경로
CREATE TABLE psychosocial_intervention_paths (
  id SERIAL PRIMARY KEY,
  trigger_type VARCHAR(50) NOT NULL CHECK (trigger_type IN (
    'start_back_high', 'orebro_high', 'fear_avoidance', 'catastrophizing', 'kinesiophobia'
  )),
  trigger_threshold JSONB NOT NULL,
  intervention_name VARCHAR(200) NOT NULL,
  intervention_name_ko VARCHAR(200),
  intervention_type VARCHAR(50) NOT NULL CHECK (intervention_type IN (
    'graded_exposure', 'pne', 'cbt_referral', 'activity_pacing', 'motivational_interview'
  )),
  protocol_steps JSONB,
  exercise_modifications JSONB,
  education_content_tags TEXT[] DEFAULT '{}',
  evidence_level VARCHAR(10) CHECK (evidence_level IN ('A', 'B', 'C', 'D')),
  cpg_reference VARCHAR(500),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_psychosocial_trigger ON psychosocial_intervention_paths(trigger_type);

-- ============================================================
-- ALTER existing tables — reasoning graph FK 연결
-- ============================================================

-- recommendations에 reasoning 연결
ALTER TABLE recommendations 
  ADD COLUMN IF NOT EXISTS reasoning_chain_id INT REFERENCES reasoning_chains(id),
  ADD COLUMN IF NOT EXISTS classification_id INT REFERENCES clinical_classifications(id);

-- encounter_notes에 classification 기록
ALTER TABLE encounter_notes 
  ADD COLUMN IF NOT EXISTS classification_id INT REFERENCES clinical_classifications(id),
  ADD COLUMN IF NOT EXISTS reasoning_chain_id INT REFERENCES reasoning_chains(id);

-- ============================================================
-- RLS Policies
-- ============================================================

-- Enable RLS on all new tables
ALTER TABLE impairments ENABLE ROW LEVEL SECURITY;
ALTER TABLE movement_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE reasoning_frameworks ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_classifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reasoning_chains ENABLE ROW LEVEL SECURITY;
ALTER TABLE classification_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_protocols ENABLE ROW LEVEL SECURITY;
ALTER TABLE psychosocial_intervention_paths ENABLE ROW LEVEL SECURITY;

-- All reasoning graph tables are READ-ONLY for authenticated users (knowledge base)
-- Write is service_role only (backend seeding)

CREATE POLICY "reasoning_read_impairments" ON impairments
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "reasoning_read_movement_patterns" ON movement_patterns
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "reasoning_read_frameworks" ON reasoning_frameworks
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "reasoning_read_classifications" ON clinical_classifications
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "reasoning_read_chains" ON reasoning_chains
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "reasoning_read_indicators" ON classification_indicators
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "reasoning_read_protocols" ON intervention_protocols
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "reasoning_read_psychosocial" ON psychosocial_intervention_paths
  FOR SELECT TO authenticated USING (is_active = true);

-- Comments
COMMENT ON TABLE impairments IS 'Clinical Reasoning Graph: 손상/결손 유형 (ROM deficit, muscle weakness, motor control deficit 등)';
COMMENT ON TABLE movement_patterns IS 'Clinical Reasoning Graph: 운동 패턴 (flexion intolerance, compensation, dyskinesis 등)';
COMMENT ON TABLE reasoning_frameworks IS 'Clinical Reasoning Graph: 임상 추론 프레임워크 (McKenzie, Sahrmann, JOSPT CPG 등)';
COMMENT ON TABLE clinical_classifications IS 'Clinical Reasoning Graph: 분류 카테고리 (Derangement, Mobility Deficit 등)';
COMMENT ON TABLE reasoning_chains IS 'Clinical Reasoning Graph: 추론 체인 — symptom→impairment→pattern→classification→intervention';
COMMENT ON TABLE classification_indicators IS 'Clinical Reasoning Graph: 분류 판별 기준 (가중치 기반 확률 매칭)';
COMMENT ON TABLE intervention_protocols IS 'Clinical Reasoning Graph: 분류별 중재 매핑 (exercise, manual, education)';
COMMENT ON TABLE psychosocial_intervention_paths IS 'Clinical Reasoning Graph: 심리사회적 개입 경로 (STarT Back High → Graded Exposure)';
;
