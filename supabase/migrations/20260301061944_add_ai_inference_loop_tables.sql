
-- ============================================================
-- AI Inference Loop — Phase 1 (단순 버전)
-- 목표: 루프가 돌아가기 시작하는 최소 구성
-- ============================================================

-- 1. ai_inference_log — 불변 AI 출력 레지스트리
CREATE TABLE IF NOT EXISTS ai_inference_log (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- 어떤 모델이
  model_key             TEXT NOT NULL,   -- 'soap_generator' | 'exercise_planner' | 'risk_assessor'
  model_version         TEXT NOT NULL,   -- 'gpt-4o-2024-11'
  agent_type            TEXT NOT NULL,   -- 'AgentOrchestrator' | 'ClinicalPlannerAgent'

  -- 누구에게, 어디서
  subject_person_id     UUID REFERENCES persons(id) ON DELETE SET NULL,
  encounter_id          UUID REFERENCES encounters(id) ON DELETE SET NULL,
  organization_id       UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

  -- 입력 지문 (드리프트 감지용, PHI 없음)
  input_hash            TEXT,            -- SHA256 of sanitized input

  -- 출력
  output_type           TEXT NOT NULL,   -- 'soap_note' | 'exercise_plan' | 'care_plan' | 'risk_score'
  output_snapshot       JSONB NOT NULL DEFAULT '{}',  -- AI 생성 원본 (불변)
  confidence            FLOAT CHECK (confidence >= 0 AND confidence <= 1),
  latency_ms            INTEGER,
  token_count           INTEGER,

  -- 도메인 테이블 연결
  target_resource_type  TEXT,            -- 'encounter_notes' | 'care_plans' | 'goals'
  target_resource_id    UUID,

  -- 치료사 피드백 (단순 3단계)
  review_status         TEXT NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending', 'accepted', 'modified', 'rejected')),
  reviewed_by           UUID REFERENCES persons(id) ON DELETE SET NULL,
  reviewed_at           TIMESTAMPTZ,

  -- 불변 보장: created_at만 존재, updated_at 없음
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_ai_log_model        ON ai_inference_log(model_key, model_version, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_log_org_type     ON ai_inference_log(organization_id, output_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_log_encounter    ON ai_inference_log(encounter_id) WHERE encounter_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_log_person       ON ai_inference_log(subject_person_id) WHERE subject_person_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_log_status       ON ai_inference_log(review_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_log_input_hash   ON ai_inference_log(input_hash) WHERE input_hash IS NOT NULL;

-- RLS
ALTER TABLE ai_inference_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members can insert ai_inference_log"
  ON ai_inference_log FOR INSERT
  WITH CHECK (is_org_member(organization_id));

CREATE POLICY "org members can select ai_inference_log"
  ON ai_inference_log FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "service role can update review_status"
  ON ai_inference_log FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 2. encounter_notes 컬럼 추가
-- ============================================================
ALTER TABLE encounter_notes
  ADD COLUMN IF NOT EXISTS ai_inference_id   UUID REFERENCES ai_inference_log(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ai_draft_snapshot JSONB,    -- AI가 생성한 원본 초안
  ADD COLUMN IF NOT EXISTS review_action     TEXT      -- 'accepted' | 'modified' | 'rejected'
    CHECK (review_action IN ('accepted', 'modified', 'rejected'));

CREATE INDEX IF NOT EXISTS idx_encounter_notes_ai_log
  ON encounter_notes(ai_inference_id) WHERE ai_inference_id IS NOT NULL;

-- ============================================================
-- 3. 집계 뷰 — 승인률 KPI (실시간)
-- ============================================================
CREATE OR REPLACE VIEW v_ai_acceptance_rate AS
SELECT
  organization_id,
  model_key,
  model_version,
  output_type,
  DATE_TRUNC('day', created_at) AS date,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE review_status = 'accepted')  AS accepted,
  COUNT(*) FILTER (WHERE review_status = 'modified')  AS modified,
  COUNT(*) FILTER (WHERE review_status = 'rejected')  AS rejected,
  COUNT(*) FILTER (WHERE review_status = 'pending')   AS pending,
  ROUND(
    COUNT(*) FILTER (WHERE review_status = 'accepted')::NUMERIC
    / NULLIF(COUNT(*) FILTER (WHERE review_status != 'pending'), 0) * 100,
    1
  ) AS acceptance_rate_pct,
  AVG(latency_ms) AS avg_latency_ms,
  AVG(confidence) AS avg_confidence
FROM ai_inference_log
GROUP BY organization_id, model_key, model_version, output_type, DATE_TRUNC('day', created_at);
;
