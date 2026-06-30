-- Low-risk SECURITY DEFINER view remediation
-- Scope: convert invoker-safe public views to security_invoker
-- Intentionally excluded:
--   - public.v_icf_core_set_details (wait for icf_reference RLS hardening to be applied live)
--   - public.v_client_comprehensive_profile
--   - public.v_client_snapshot
--   - public.v_dashboard_kpi
--   - public.v_persons
--   - public.table_groups_view

alter view public.recommendation_exercises
  set (security_invoker = true);
alter view public.exercise_promotion_candidates
  set (security_invoker = true);
alter view public.v_protocol_exercise_mapping
  set (security_invoker = true);
alter view public.v_ai_acceptance_rate
  set (security_invoker = true);
alter view public.v_episode_summary
  set (security_invoker = true);
alter view public.v_class_analytics
  set (security_invoker = true);
