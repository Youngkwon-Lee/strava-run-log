-- episodes: provider가 "내 org의 client별 status" 조회 시 사용
CREATE INDEX IF NOT EXISTS idx_episodes_org_person_status
  ON public.episodes (organization_id, subject_person_id, status)
  WHERE deleted_at IS NULL;

-- chat_context_snapshots: LLM이 최신 snapshot 조회 시 computed_at 정렬 포함
CREATE INDEX IF NOT EXISTS idx_snapshots_scope_computed
  ON public.chat_context_snapshots (scope_type, scope_id, computed_at DESC);

-- job_queue: snapshot_refresh pending 중복 체크 쿼리 최적화
-- queue_snapshot_refresh() 함수의 WHERE NOT EXISTS 서브쿼리
CREATE INDEX IF NOT EXISTS idx_job_queue_snapshot_dedup
  ON public.job_queue (job_type, status, (payload->>'scope_id'))
  WHERE job_type = 'snapshot_refresh' AND status = 'pending';;
