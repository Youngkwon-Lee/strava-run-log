-- ============================================================
-- T0.2: ai_feedback — AI 추론 피드백 (Immutable Append-Only)
-- ============================================================

CREATE TABLE public.ai_feedback (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id      UUID        NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  -- AI 추론 연결 (ai_inference_log FK)
  inference_id         UUID        REFERENCES public.ai_inference_log(id) ON DELETE SET NULL,

  -- 리뷰어 (치료사)
  reviewer_person_id   UUID        NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  encounter_id         UUID        REFERENCES public.encounters(id) ON DELETE SET NULL,

  -- 피드백 분류
  action               TEXT        NOT NULL
    CHECK (action IN ('accepted', 'modified', 'rejected')),

  modification_type    TEXT
    CHECK (modification_type IN (
      'exercise_removed',
      'exercise_added',
      'exercise_intensity_changed',
      'diagnosis_changed',
      'treatment_approach_changed',
      'dosage_changed',
      'goal_changed',
      'timeline_changed',
      'safety_concern',
      'other'
    )),

  rejection_reason     TEXT
    CHECK (rejection_reason IN (
      'patient_contraindication',
      'equipment_unavailable',
      'patient_preference',
      'clinical_judgment',
      'insurance_limitation',
      'wrong_body_region',
      'wrong_difficulty',
      'already_tried',
      'other'
    )),

  -- 수정 상세
  original_content     JSONB,      -- AI 원본 추천
  modified_content     JSONB,      -- 치료사 수정본
  rejection_note       TEXT,       -- 자유 텍스트 사유

  -- 성능 지표
  review_duration_ms   INTEGER,    -- 리뷰 소요 시간

  -- Immutable: updated_at 없음
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- action=modified 이면 modification_type 필수
  CONSTRAINT chk_modified_requires_type
    CHECK (action != 'modified' OR modification_type IS NOT NULL),

  -- action=rejected 이면 rejection_reason 필수
  CONSTRAINT chk_rejected_requires_reason
    CHECK (action != 'rejected' OR rejection_reason IS NOT NULL)
);

-- Indexes
CREATE INDEX idx_ai_feedback_inference
  ON public.ai_feedback(inference_id);

CREATE INDEX idx_ai_feedback_org_action
  ON public.ai_feedback(organization_id, action, created_at DESC);

CREATE INDEX idx_ai_feedback_reviewer
  ON public.ai_feedback(reviewer_person_id, created_at DESC);

CREATE INDEX idx_ai_feedback_modification_type
  ON public.ai_feedback(modification_type)
  WHERE modification_type IS NOT NULL;

-- RLS
ALTER TABLE public.ai_feedback ENABLE ROW LEVEL SECURITY;

-- SELECT: org 멤버
CREATE POLICY "ai_feedback_select_org_member"
  ON public.ai_feedback FOR SELECT
  USING (public.is_org_member(organization_id));

-- INSERT: 리뷰어 본인만
CREATE POLICY "ai_feedback_insert_reviewer"
  ON public.ai_feedback FOR INSERT
  WITH CHECK (reviewer_person_id = public.get_my_person_id());

-- UPDATE/DELETE: 정책 없음 → Immutable append-only

COMMENT ON TABLE public.ai_feedback IS
  'AI 추론 피드백 로그. Immutable append-only. 치료사가 AI 추천을 수락/수정/거절한 내역을 구조화하여 Correction Pipeline에 활용.';
;
