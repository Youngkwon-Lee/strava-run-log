-- Wave D9: remove exercises anon/public SELECT overlap.

drop policy if exists "exercises_client_or_authenticated_read" on public.exercises;
create policy "exercises_client_or_authenticated_read"
  on public.exercises
  as permissive
  for select
  to authenticated
  using (
    (((select auth.jwt()) ->> 'app_role'::text) = 'client'::text)
    or ((select auth.role()) = 'authenticated'::text)
  );
