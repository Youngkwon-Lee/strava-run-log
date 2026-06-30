-- High-risk SECURITY DEFINER view lockdown candidate
-- Review-first migration. Do not apply until external/Data API consumers are verified.
--
-- Scope:
--   C2 sign-off-required reporting views
--     - public.v_client_comprehensive_profile
--     - public.v_client_snapshot
--     - public.v_dashboard_kpi
--
-- Intent:
--   - Remove anonymous and generic authenticated Data API exposure first
--   - Preserve postgres/service_role access
--   - Re-evaluate each view later for:
--       1) private keep
--       2) security_invoker conversion
--       3) removal
--
-- Recommended rollout:
--   1) C1 was already applied in 20260314041500_lock_down_c1_security_definer_views.sql
--   2) Apply this C2 subset only after explicit sign-off for external/BI consumers

revoke all on public.v_client_comprehensive_profile from anon, authenticated;
revoke all on public.v_client_snapshot from anon, authenticated;
revoke all on public.v_dashboard_kpi from anon, authenticated;
