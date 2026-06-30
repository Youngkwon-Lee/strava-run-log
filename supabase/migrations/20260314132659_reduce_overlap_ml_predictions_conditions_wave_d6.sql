-- Wave D6: reduce overlap on ml_predictions + conditions.

-- ml_predictions
drop policy if exists "ml_pred_platform_admin" on public.ml_predictions;
drop policy if exists "ml_pred_insert_org" on public.ml_predictions;
drop policy if exists "ml_pred_select_org" on public.ml_predictions;

create policy "ml_pred_insert_org_or_platform"
  on public.ml_predictions
  as permissive
  for insert
  to public
  with check (is_org_member(organization_id) or is_platform_admin());

create policy "ml_pred_select_org_or_platform"
  on public.ml_predictions
  as permissive
  for select
  to public
  using (is_org_member(organization_id) or is_platform_admin());

create policy "ml_pred_update_platform_admin"
  on public.ml_predictions
  as permissive
  for update
  to public
  using (is_platform_admin())
  with check (is_platform_admin());

create policy "ml_pred_delete_platform_admin"
  on public.ml_predictions
  as permissive
  for delete
  to public
  using (is_platform_admin());

-- conditions
drop policy if exists "conditions_admin_access" on public.conditions;

create policy "conditions_admin_delete"
  on public.conditions
  as permissive
  for delete
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = conditions.organization_id
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );;
