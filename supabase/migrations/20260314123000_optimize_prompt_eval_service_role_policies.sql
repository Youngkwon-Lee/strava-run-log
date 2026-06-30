-- P1 performance hardening (RLS policy optimization)
-- - Split service-role access policies from public role scope
-- - Use (select auth.role()) pattern to avoid per-row auth function re-evaluation
-- Date: 2026-03-14

drop policy if exists "Service role full access on eval results"
  on public.prompt_evaluation_results;
create policy "Service role full access on eval results"
  on public.prompt_evaluation_results
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
drop policy if exists "Service role full access on eval runs"
  on public.prompt_evaluation_runs;
create policy "Service role full access on eval runs"
  on public.prompt_evaluation_runs
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
drop policy if exists "Service role full access on eval samples"
  on public.prompt_evaluation_samples;
create policy "Service role full access on eval samples"
  on public.prompt_evaluation_samples
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
