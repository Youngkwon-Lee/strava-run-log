-- Lock down the safest remaining SECURITY DEFINER views
-- Scope:
--   - public.v_persons
--   - public.table_groups_view
-- Intent:
--   - remove anon/authenticated Data API exposure
--   - preserve postgres and service_role access

revoke all on public.v_persons from anon, authenticated;
revoke all on public.table_groups_view from anon, authenticated;
