
-- Recommendation Graph: Observation → Condition → Recommendation reasoning trace
-- 기존 ai_inference_log.output_snapshot JSON에만 존재하던 AI 추천을
-- FK 기반 그래프로 구조화

CREATE TABLE IF NOT EXISTS recommendations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Context FKs (reasoning trace)
  subject_person_id UUID NOT NULL REFERENCES persons(id),
  organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  encounter_id      UUID REFERENCES encounters(id) ON DELETE SET NULL,
  episode_id        UUID REFERENCES episodes(id) ON DELETE SET NULL,
  condition_id      UUID REFERENCES conditions(id) ON DELETE SET NULL,
  observation_id    UUID REFERENCES observations(id) ON DELETE SET NULL,
  ai_inference_id   UUID REFERENCES ai_inference_log(id) ON DELETE SET NULL,

  -- Content
  recommendation_type TEXT NOT NULL,
  code              TEXT,
  code_display      TEXT,
  description       TEXT NOT NULL,
  rationale         TEXT,
  priority          TEXT NOT NULL DEFAULT 'routine',
  status            TEXT NOT NULL DEFAULT 'proposed',

  -- Source
  source_type       TEXT NOT NULL DEFAULT 'ai',

  -- Review
  reviewed_by       UUID REFERENCES persons(id) ON DELETE SET NULL,
  reviewed_at       TIMESTAMPTZ,

  -- Audit
  created_by        UUID NOT NULL REFERENCES persons(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CHECK constraints
ALTER TABLE recommendations
  ADD CONSTRAINT recommendations_type_check
    CHECK (recommendation_type IN (
      'exercise', 'assessment', 'referral', 'education',
      'lifestyle', 'monitoring', 'procedure', 'medication'
    )),
  ADD CONSTRAINT recommendations_priority_check
    CHECK (priority IN ('routine', 'urgent', 'asap', 'stat')),
  ADD CONSTRAINT recommendations_status_check
    CHECK (status IN ('proposed', 'accepted', 'rejected', 'completed', 'cancelled')),
  ADD CONSTRAINT recommendations_source_type_check
    CHECK (source_type IN ('ai', 'provider', 'guideline', 'system'));

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS recommendations_subject_person_idx
  ON recommendations(subject_person_id);
CREATE INDEX IF NOT EXISTS recommendations_encounter_idx
  ON recommendations(encounter_id) WHERE encounter_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS recommendations_condition_idx
  ON recommendations(condition_id) WHERE condition_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS recommendations_ai_inference_idx
  ON recommendations(ai_inference_id) WHERE ai_inference_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS recommendations_status_idx
  ON recommendations(status) WHERE status = 'proposed';

-- RLS (org member 기반 — ai_inference_log과 동일 패턴)
ALTER TABLE recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_members_select_recommendations"
  ON recommendations FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "providers_insert_recommendations"
  ON recommendations FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = recommendations.organization_id
        AND om.role IN ('owner', 'admin', 'provider')
    )
  );

CREATE POLICY "providers_update_recommendations"
  ON recommendations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = recommendations.organization_id
        AND om.role IN ('owner', 'admin', 'provider')
    )
  );

-- Client read-only (자기 데이터)
CREATE POLICY "clients_select_own_recommendations"
  ON recommendations FOR SELECT
  USING (subject_person_id = get_my_person_id());

COMMENT ON TABLE recommendations IS
  'AI reasoning graph — Observation→Condition→Recommendation FK 연결. '
  'ai_inference_log.output_snapshot JSON에서 구조화된 추천으로 전환. '
  'source_type: ai(LLM 생성), provider(수동), guideline(프로토콜), system(자동 규칙)';
;
