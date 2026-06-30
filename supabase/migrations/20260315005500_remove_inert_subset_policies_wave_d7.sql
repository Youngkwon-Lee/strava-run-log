-- Wave D7: remove inert/subset permissive policies.
-- Scope: person_events, leads

-- person_events: false permissive policies are inert when broader permissive policy exists.
drop policy if exists "person_events_no_update" on public.person_events;
drop policy if exists "person_events_no_delete" on public.person_events;
-- leads: admin-only delete is a subset of existing org_write ALL policy.
drop policy if exists "leads_admin_delete" on public.leads;
