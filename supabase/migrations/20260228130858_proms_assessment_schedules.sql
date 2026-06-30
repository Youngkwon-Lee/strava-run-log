-- PROMs Assessment Schedules
-- 6가지 스케줄 타입으로 평가 도구 자동 발송 관리

CREATE TABLE IF NOT EXISTS public.assessment_schedules (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  person_id         UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  episode_id        UUID REFERENCES public.episodes(id) ON DELETE SET NULL,
  template_key      TEXT NOT NULL,
  schedule_type     TEXT NOT NULL CHECK (schedule_type IN (
    'start_end', 'periodic', 'specific_dates', 'post_discharge', 'milestone', 'manual'
  )),
  interval_days     INTEGER,
  specific_dates    TEXT[],
  starts_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at           TIMESTAMPTZ,
  next_due_at       TIMESTAMPTZ,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
    'active', 'paused', 'completed', 'cancelled'
  )),
  created_by        UUID REFERENCES public.persons(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_assessment_schedules_org      ON public.assessment_schedules(organization_id);
CREATE INDEX IF NOT EXISTS idx_assessment_schedules_person   ON public.assessment_schedules(person_id);
CREATE INDEX IF NOT EXISTS idx_assessment_schedules_due      ON public.assessment_schedules(next_due_at) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_assessment_schedules_episode  ON public.assessment_schedules(episode_id) WHERE episode_id IS NOT NULL;

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION public.set_assessment_schedules_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assessment_schedules_updated_at ON public.assessment_schedules;
CREATE TRIGGER trg_assessment_schedules_updated_at
  BEFORE UPDATE ON public.assessment_schedules
  FOR EACH ROW EXECUTE FUNCTION public.set_assessment_schedules_updated_at();

-- RLS 활성화
ALTER TABLE public.assessment_schedules ENABLE ROW LEVEL SECURITY;

-- 정책: 조직 멤버만 조회
CREATE POLICY "assessment_schedules_select"
  ON public.assessment_schedules FOR SELECT
  USING (is_org_member(organization_id));

-- 정책: org admin/provider만 삽입
CREATE POLICY "assessment_schedules_insert"
  ON public.assessment_schedules FOR INSERT
  WITH CHECK (is_org_member(organization_id));

-- 정책: org admin/provider만 수정
CREATE POLICY "assessment_schedules_update"
  ON public.assessment_schedules FOR UPDATE
  USING (is_org_member(organization_id));

-- 정책: org admin만 삭제
CREATE POLICY "assessment_schedules_delete"
  ON public.assessment_schedules FOR DELETE
  USING (is_org_admin(organization_id));;
