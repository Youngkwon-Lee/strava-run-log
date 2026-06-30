-- Harden ICF coverage reference surfaces before production.
--
-- Advisor findings addressed:
-- - security_definer_view on ICF coverage views
-- - RLS disabled on public.assessment_form_icf_tags
-- - mutable search_path on public.fn_resolve_protocol_pack(text)
-- - anon/authenticated EXECUTE on SECURITY DEFINER functions

begin;
-- Reference table used by server-side ICF gap resolution.
-- It is populated by migrations and read through service-role domain code.
alter table public.assessment_form_icf_tags enable row level security;
drop policy if exists assessment_form_icf_tags_service_role_all
  on public.assessment_form_icf_tags;
create policy assessment_form_icf_tags_service_role_all
  on public.assessment_form_icf_tags
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
revoke all on table public.assessment_form_icf_tags from public, anon, authenticated;
grant select, insert, update, delete on table public.assessment_form_icf_tags to service_role;
-- These views are internal analysis/reference surfaces consumed by
-- service-role server code. Make them invoker-rights views and remove
-- direct Data API access for browser roles.
alter view public.v_icf_core_set_coverage set (security_invoker = true);
alter view public.v_icf_coverage_summary set (security_invoker = true);
alter view public.v_icf_mandatory_gaps set (security_invoker = true);
alter view public.v_assessment_icf_coverage set (security_invoker = true);
alter view public.v_condition_assessment_icf_gap set (security_invoker = true);
revoke all on table public.v_icf_core_set_coverage from public, anon, authenticated;
revoke all on table public.v_icf_coverage_summary from public, anon, authenticated;
revoke all on table public.v_icf_mandatory_gaps from public, anon, authenticated;
revoke all on table public.v_assessment_icf_coverage from public, anon, authenticated;
revoke all on table public.v_condition_assessment_icf_gap from public, anon, authenticated;
grant select on table public.v_icf_core_set_coverage to service_role;
grant select on table public.v_icf_coverage_summary to service_role;
grant select on table public.v_icf_mandatory_gaps to service_role;
grant select on table public.v_assessment_icf_coverage to service_role;
grant select on table public.v_condition_assessment_icf_gap to service_role;
-- Immutable SQL helper used by the episode trigger and mirrored in app code.
alter function public.fn_resolve_protocol_pack(text)
  set search_path = public, pg_temp;
-- Trigger/RPC SECURITY DEFINER functions must not be callable directly
-- through PostgREST by anon/authenticated browser roles.
revoke execute on function public.trg_episode_resolve_protocol_pack()
  from public, anon, authenticated;
grant execute on function public.trg_episode_resolve_protocol_pack()
  to service_role;
revoke execute on function public.v_client_icf_coverage(uuid, text)
  from public, anon, authenticated;
grant execute on function public.v_client_icf_coverage(uuid, text)
  to service_role;
comment on table public.assessment_form_icf_tags is
  'Maps assessment form templates to the ICF domains they measure. Server/service-role reference surface only; browser roles have no direct grants.';
commit;
