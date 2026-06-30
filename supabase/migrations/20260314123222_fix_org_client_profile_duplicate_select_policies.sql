-- Fix residual duplicate permissive SELECT policies on org_client_profile.

drop policy if exists "client_profile_org_read" on public.org_client_profile;
drop policy if exists "client_profile_admin_write" on public.org_client_profile;

create policy "client_profile_admin_insert"
  on public.org_client_profile
  as permissive
  for insert
  to public
  with check (is_org_admin(organization_id));

create policy "client_profile_admin_update"
  on public.org_client_profile
  as permissive
  for update
  to public
  using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));

create policy "client_profile_admin_delete"
  on public.org_client_profile
  as permissive
  for delete
  to public
  using (is_org_admin(organization_id));;
