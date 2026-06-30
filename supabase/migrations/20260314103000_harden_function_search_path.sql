-- P0 hardening: set explicit search_path on mutable functions
-- Source: live Supabase advisor (function_search_path_mutable)
-- Date: 2026-03-14

alter function public.deduct_package_session()
  set search_path = public, extensions, pg_temp;
alter function public.hybrid_search(
  query_embedding text,
  query_text text,
  match_threshold double precision,
  match_count integer,
  filter_source_type text,
  filter_category text,
  vector_weight double precision,
  text_weight double precision
)
  set search_path = public, extensions, pg_temp;
alter function public.log_booking_event()
  set search_path = public, extensions, pg_temp;
alter function public.queue_snapshot_refresh(
  p_scope_type text,
  p_scope_id uuid,
  p_person_id uuid,
  p_org_id uuid
)
  set search_path = public, extensions, pg_temp;
alter function public.set_assessment_schedules_updated_at()
  set search_path = public, extensions, pg_temp;
alter function public.set_mcd_updated_at()
  set search_path = public, extensions, pg_temp;
alter function public.set_updated_at()
  set search_path = public, extensions, pg_temp;
alter function public.trg_check_reassessment_due()
  set search_path = public, extensions, pg_temp;
alter function public.trg_patient_state_updated_at()
  set search_path = public, extensions, pg_temp;
alter function public.trg_queue_activity_snapshot()
  set search_path = public, extensions, pg_temp;
alter function public.trg_queue_encounter_snapshot()
  set search_path = public, extensions, pg_temp;
