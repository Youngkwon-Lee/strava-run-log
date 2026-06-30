-- P0 hardening: lock down public.icf_reference
-- Source: Supabase advisor `rls_disabled_in_public`
--
-- Design choice:
--   - Treat `icf_reference` as read-only reference data
--   - Allow authenticated read access
--   - Remove anon write/read grants by default
--   - Keep service_role behavior unchanged
--
-- If a true public route later needs this data, add an explicit anon SELECT
-- policy in a follow-up migration instead of leaving the table broadly exposed.

revoke all on table public.icf_reference from anon;
revoke all on table public.icf_reference from authenticated;
grant select on table public.icf_reference to authenticated;
alter table public.icf_reference enable row level security;
drop policy if exists icf_reference_read_authenticated on public.icf_reference;
create policy icf_reference_read_authenticated
  on public.icf_reference
  for select
  to authenticated
  using (true);
-- Optional follow-up if a real anonymous read path is introduced:
-- create policy icf_reference_read_anon
--   on public.icf_reference
--   for select
--   to anon
--   using (true);;
