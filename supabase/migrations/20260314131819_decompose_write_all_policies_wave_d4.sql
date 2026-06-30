-- Wave D4: decompose write-oriented ALL policies to remove SELECT overlap.
-- Scope: assessment_form_templates, automation_rules, client_education_deliveries,
--        invoice_line_items, ml_client_exercise_progress

-- assessment_form_templates
drop policy if exists "aft_admin_manage" on public.assessment_form_templates;

create policy "aft_admin_insert"
  on public.assessment_form_templates
  as permissive
  for insert
  to authenticated
  with check (is_platform_admin());

create policy "aft_admin_update"
  on public.assessment_form_templates
  as permissive
  for update
  to authenticated
  using (is_platform_admin())
  with check (is_platform_admin());

create policy "aft_admin_delete"
  on public.assessment_form_templates
  as permissive
  for delete
  to authenticated
  using (is_platform_admin());

-- automation_rules
drop policy if exists "automation_rules_org_admin_write" on public.automation_rules;

create policy "automation_rules_org_admin_insert"
  on public.automation_rules
  as permissive
  for insert
  to public
  with check (is_org_admin(organization_id));

create policy "automation_rules_org_admin_update"
  on public.automation_rules
  as permissive
  for update
  to public
  using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));

create policy "automation_rules_org_admin_delete"
  on public.automation_rules
  as permissive
  for delete
  to public
  using (is_org_admin(organization_id));

-- client_education_deliveries
drop policy if exists "education_deliveries_staff_write" on public.client_education_deliveries;

create policy "education_deliveries_staff_insert"
  on public.client_education_deliveries
  as permissive
  for insert
  to public
  with check (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
  );

create policy "education_deliveries_staff_update"
  on public.client_education_deliveries
  as permissive
  for update
  to public
  using (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
  )
  with check (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
  );

create policy "education_deliveries_staff_delete"
  on public.client_education_deliveries
  as permissive
  for delete
  to public
  using (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
  );

-- invoice_line_items
drop policy if exists "org_admin_write_invoice_line_items" on public.invoice_line_items;

create policy "org_admin_insert_invoice_line_items"
  on public.invoice_line_items
  as permissive
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from invoices inv
      join organization_members om on om.organization_id = inv.organization_id
      where (
        inv.id = invoice_line_items.invoice_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );

create policy "org_admin_update_invoice_line_items"
  on public.invoice_line_items
  as permissive
  for update
  to authenticated
  using (
    exists (
      select 1
      from invoices inv
      join organization_members om on om.organization_id = inv.organization_id
      where (
        inv.id = invoice_line_items.invoice_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  )
  with check (
    exists (
      select 1
      from invoices inv
      join organization_members om on om.organization_id = inv.organization_id
      where (
        inv.id = invoice_line_items.invoice_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );

create policy "org_admin_delete_invoice_line_items"
  on public.invoice_line_items
  as permissive
  for delete
  to authenticated
  using (
    exists (
      select 1
      from invoices inv
      join organization_members om on om.organization_id = inv.organization_id
      where (
        inv.id = invoice_line_items.invoice_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );

-- ml_client_exercise_progress
drop policy if exists "mlpep_modify" on public.ml_client_exercise_progress;

create policy "mlpep_insert_platform_admin"
  on public.ml_client_exercise_progress
  as permissive
  for insert
  to public
  with check (is_platform_admin());

create policy "mlpep_update_platform_admin"
  on public.ml_client_exercise_progress
  as permissive
  for update
  to public
  using (is_platform_admin())
  with check (is_platform_admin());

create policy "mlpep_delete_platform_admin"
  on public.ml_client_exercise_progress
  as permissive
  for delete
  to public
  using (is_platform_admin());;
