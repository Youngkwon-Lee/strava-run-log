-- ============================================================
-- T0.1: clinical_tasks — FHIR Task 패턴 기반 임상 워크플로우 큐
-- ============================================================

CREATE TABLE public.clinical_tasks (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id     UUID        NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  -- Assignment
  assigned_to         UUID        REFERENCES public.persons(id) ON DELETE SET NULL,
  assigned_role       TEXT,                        -- 역할 기반 라우팅 fallback
  requested_by        UUID        REFERENCES public.persons(id) ON DELETE SET NULL,

  -- FHIR Task 3중 상태
  task_type           TEXT        NOT NULL
    CHECK (task_type IN (
      'reassessment_due',
      'care_plan_expiring',
      'note_sign_off',
      'discharge_review',
      'intake_review',
      'insurance_auth_needed',
      'plateau_detected',
      'overdue_follow_up'
    )),
  status              TEXT        NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  business_status     TEXT,                        -- 자유 형식 ("보험사 회신 대기")
  status_reason       TEXT,                        -- 상태 변경 사유

  -- Priority & Timing
  priority            TEXT        NOT NULL DEFAULT 'routine'
    CHECK (priority IN ('routine', 'urgent', 'stat')),
  due_date            TIMESTAMPTZ,
  completed_at        TIMESTAMPTZ,
  completed_by        UUID        REFERENCES public.persons(id) ON DELETE SET NULL,

  -- Context
  subject_person_id   UUID        REFERENCES public.persons(id) ON DELETE CASCADE,
  context_json        JSONB       NOT NULL DEFAULT '{}',

  -- Metadata
  source              TEXT        NOT NULL DEFAULT 'system'
    CHECK (source IN ('system', 'provider', 'ai')),
  note                TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes (Postgres best practices: 자주 쓰는 WHERE 조건에 partial index)
CREATE INDEX idx_clinical_tasks_assignee_pending
  ON public.clinical_tasks(assigned_to, due_date)
  WHERE status = 'pending';

CREATE INDEX idx_clinical_tasks_org_status
  ON public.clinical_tasks(organization_id, status, due_date);

CREATE INDEX idx_clinical_tasks_subject_type
  ON public.clinical_tasks(subject_person_id, task_type)
  WHERE status = 'pending';

-- updated_at 자동 갱신
CREATE TRIGGER set_clinical_tasks_updated_at
  BEFORE UPDATE ON public.clinical_tasks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS
ALTER TABLE public.clinical_tasks ENABLE ROW LEVEL SECURITY;

-- SELECT: org 멤버 전체
CREATE POLICY "clinical_tasks_select_org_member"
  ON public.clinical_tasks FOR SELECT
  USING (public.is_org_member(organization_id));

-- INSERT: org 멤버 전체 (system trigger 포함)
CREATE POLICY "clinical_tasks_insert_org_member"
  ON public.clinical_tasks FOR INSERT
  WITH CHECK (public.is_org_member(organization_id));

-- UPDATE: 담당자 본인 또는 org admin
CREATE POLICY "clinical_tasks_update_assignee_or_admin"
  ON public.clinical_tasks FOR UPDATE
  USING (
    assigned_to = public.get_my_person_id()
    OR public.is_org_admin(organization_id)
  );

-- DELETE: org admin만
CREATE POLICY "clinical_tasks_delete_admin"
  ON public.clinical_tasks FOR DELETE
  USING (public.is_org_admin(organization_id));

COMMENT ON TABLE public.clinical_tasks IS
  'FHIR Task 패턴 기반 임상 워크플로우 큐. reassessment, discharge, note sign-off 등 치료사 할 일 inbox.';
;
