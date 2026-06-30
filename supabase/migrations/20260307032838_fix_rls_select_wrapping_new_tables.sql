-- ============================================================
-- Fix: RLS (select ...) wrapping — clinical_tasks + ai_feedback
-- security-rls-performance: 함수를 InitPlan으로 캐싱하여 행마다 실행 방지
-- ============================================================

-- clinical_tasks: 기존 정책 삭제 후 재생성
DROP POLICY IF EXISTS "clinical_tasks_select_org_member"        ON public.clinical_tasks;
DROP POLICY IF EXISTS "clinical_tasks_insert_org_member"        ON public.clinical_tasks;
DROP POLICY IF EXISTS "clinical_tasks_update_assignee_or_admin" ON public.clinical_tasks;
DROP POLICY IF EXISTS "clinical_tasks_delete_admin"             ON public.clinical_tasks;

CREATE POLICY "clinical_tasks_select_org_member"
  ON public.clinical_tasks FOR SELECT
  USING ((select public.is_org_member(organization_id)));

CREATE POLICY "clinical_tasks_insert_org_member"
  ON public.clinical_tasks FOR INSERT
  WITH CHECK ((select public.is_org_member(organization_id)));

CREATE POLICY "clinical_tasks_update_assignee_or_admin"
  ON public.clinical_tasks FOR UPDATE
  USING (
    assigned_to = (select public.get_my_person_id())
    OR (select public.is_org_admin(organization_id))
  );

CREATE POLICY "clinical_tasks_delete_admin"
  ON public.clinical_tasks FOR DELETE
  USING ((select public.is_org_admin(organization_id)));

-- ai_feedback: 기존 정책 삭제 후 재생성
DROP POLICY IF EXISTS "ai_feedback_select_org_member" ON public.ai_feedback;
DROP POLICY IF EXISTS "ai_feedback_insert_reviewer"   ON public.ai_feedback;

CREATE POLICY "ai_feedback_select_org_member"
  ON public.ai_feedback FOR SELECT
  USING ((select public.is_org_member(organization_id)));

CREATE POLICY "ai_feedback_insert_reviewer"
  ON public.ai_feedback FOR INSERT
  WITH CHECK (reviewer_person_id = (select public.get_my_person_id()));;
