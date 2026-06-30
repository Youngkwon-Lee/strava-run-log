-- Wave D2: decompose SELECT-overlapping ALL policies (low-risk set).
-- Scope: data_sharing_consent, ml_model_registry

-- data_sharing_consent
drop policy if exists "sharing_manage_admin_or_self" on public.data_sharing_consent;
create policy "sharing_insert_admin_or_self"
  on public.data_sharing_consent
  as permissive
  for insert
  to public
  with check (is_org_admin(from_org_id) or (subject_person_id = get_my_person_id()));
create policy "sharing_update_admin_or_self"
  on public.data_sharing_consent
  as permissive
  for update
  to public
  using (is_org_admin(from_org_id) or (subject_person_id = get_my_person_id()))
  with check (is_org_admin(from_org_id) or (subject_person_id = get_my_person_id()));
create policy "sharing_delete_admin_or_self"
  on public.data_sharing_consent
  as permissive
  for delete
  to public
  using (is_org_admin(from_org_id) or (subject_person_id = get_my_person_id()));
-- ml_model_registry
drop policy if exists "ml_registry_manage_admin_or_platform" on public.ml_model_registry;
create policy "ml_registry_insert_admin_or_platform"
  on public.ml_model_registry
  as permissive
  for insert
  to public
  with check (is_org_admin(organization_id) or is_platform_admin());
create policy "ml_registry_update_admin_or_platform"
  on public.ml_model_registry
  as permissive
  for update
  to public
  using (is_org_admin(organization_id) or is_platform_admin())
  with check (is_org_admin(organization_id) or is_platform_admin());
create policy "ml_registry_delete_admin_or_platform"
  on public.ml_model_registry
  as permissive
  for delete
  to public
  using (is_org_admin(organization_id) or is_platform_admin());
