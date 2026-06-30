-- Wave C2: additional duplicate permissive policy consolidation.

-- 1) Merge duplicate SELECT policies (same role/action).
drop policy if exists "org_client_profile_org_read" on public.org_client_profile;
drop policy if exists "client_profile_self_read" on public.org_client_profile;
create policy "org_client_profile_org_or_self_read"
  on public.org_client_profile
  as permissive
  for select
  to public
  using (is_org_member(organization_id) or (person_id = get_my_person_id()));

drop policy if exists "org_clients_client_view" on public.org_clients;
drop policy if exists "org_clients_staff_view" on public.org_clients;
create policy "org_clients_client_or_staff_view"
  on public.org_clients
  as permissive
  for select
  to public
  using (
    is_my_person(person_id)
    or exists (
      select 1
      from organization_members m
      where (
        m.organization_id = org_clients.organization_id
        and m.person_id = get_my_person_id()
        and m.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
        and m.status = 'active'::text
        and m.deleted_at is null
      )
    )
  );

drop policy if exists "provider_profile_org_read" on public.org_provider_profile;
drop policy if exists "provider_profile_self_read" on public.org_provider_profile;
create policy "org_provider_profile_org_or_self_read"
  on public.org_provider_profile
  as permissive
  for select
  to public
  using (is_org_member(organization_id) or (person_id = get_my_person_id()));

-- 2) Split ALL policies into I/U/D to avoid SELECT duplication side effects.
drop policy if exists "provider can manage icf assessments" on public.person_icf_assessments;
create policy "person_icf_assessments_provider_insert"
  on public.person_icf_assessments
  as permissive
  for insert
  to public
  with check (
    encounter_id in (
      select encounters.id
      from encounters
      where (
        encounters.organization_id in (
          select get_my_org_ids.organization_id
          from get_my_org_ids() get_my_org_ids(organization_id)
        )
      )
    )
  );
create policy "person_icf_assessments_provider_update"
  on public.person_icf_assessments
  as permissive
  for update
  to public
  using (
    encounter_id in (
      select encounters.id
      from encounters
      where (
        encounters.organization_id in (
          select get_my_org_ids.organization_id
          from get_my_org_ids() get_my_org_ids(organization_id)
        )
      )
    )
  )
  with check (
    encounter_id in (
      select encounters.id
      from encounters
      where (
        encounters.organization_id in (
          select get_my_org_ids.organization_id
          from get_my_org_ids() get_my_org_ids(organization_id)
        )
      )
    )
  );
create policy "person_icf_assessments_provider_delete"
  on public.person_icf_assessments
  as permissive
  for delete
  to public
  using (
    encounter_id in (
      select encounters.id
      from encounters
      where (
        encounters.organization_id in (
          select get_my_org_ids.organization_id
          from get_my_org_ids() get_my_org_ids(organization_id)
        )
      )
    )
  );

drop policy if exists "person_medication_allergies_clinician_write" on public.person_medication_allergies;
create policy "person_medication_allergies_clinician_insert"
  on public.person_medication_allergies
  as permissive
  for insert
  to public
  with check (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );
create policy "person_medication_allergies_clinician_update"
  on public.person_medication_allergies
  as permissive
  for update
  to public
  using (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  )
  with check (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );
create policy "person_medication_allergies_clinician_delete"
  on public.person_medication_allergies
  as permissive
  for delete
  to public
  using (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );

drop policy if exists "platform_admins_super_manage" on public.platform_admins;
create policy "platform_admins_super_insert"
  on public.platform_admins
  as permissive
  for insert
  to public
  with check (get_platform_admin_role() = 'super_admin'::text);
create policy "platform_admins_super_update"
  on public.platform_admins
  as permissive
  for update
  to public
  using (get_platform_admin_role() = 'super_admin'::text)
  with check (get_platform_admin_role() = 'super_admin'::text);
create policy "platform_admins_super_delete"
  on public.platform_admins
  as permissive
  for delete
  to public
  using (get_platform_admin_role() = 'super_admin'::text);

drop policy if exists "platform_admin_all" on public.prompt_evolution_rules;
create policy "prompt_evolution_rules_platform_admin_insert"
  on public.prompt_evolution_rules
  as permissive
  for insert
  to public
  with check (is_platform_admin());
create policy "prompt_evolution_rules_platform_admin_update"
  on public.prompt_evolution_rules
  as permissive
  for update
  to public
  using (is_platform_admin())
  with check (is_platform_admin());
create policy "prompt_evolution_rules_platform_admin_delete"
  on public.prompt_evolution_rules
  as permissive
  for delete
  to public
  using (is_platform_admin());

drop policy if exists "platform_admin_full_access" on public.prompt_templates;
create policy "prompt_templates_platform_admin_insert"
  on public.prompt_templates
  as permissive
  for insert
  to public
  with check (is_platform_admin());
create policy "prompt_templates_platform_admin_update"
  on public.prompt_templates
  as permissive
  for update
  to public
  using (is_platform_admin())
  with check (is_platform_admin());
create policy "prompt_templates_platform_admin_delete"
  on public.prompt_templates
  as permissive
  for delete
  to public
  using (is_platform_admin());;
