-- P1.3: Reduce duplicate permissive policy overlap on prompt_evaluation* tables.
-- Scope platform-admin policies from PUBLIC to dashboard_user and use initplan-friendly checks.

drop policy if exists "Platform admins manage eval results" on public.prompt_evaluation_results;
create policy "Platform admins manage eval results"
  on public.prompt_evaluation_results
  as permissive
  for all
  to dashboard_user
  using ((select is_platform_admin()));

drop policy if exists "Platform admins manage eval runs" on public.prompt_evaluation_runs;
create policy "Platform admins manage eval runs"
  on public.prompt_evaluation_runs
  as permissive
  for all
  to dashboard_user
  using ((select is_platform_admin()));

drop policy if exists "Platform admins manage eval samples" on public.prompt_evaluation_samples;
create policy "Platform admins manage eval samples"
  on public.prompt_evaluation_samples
  as permissive
  for all
  to dashboard_user
  using ((select is_platform_admin()));;
