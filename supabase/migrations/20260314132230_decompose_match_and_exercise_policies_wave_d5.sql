-- Wave D5: decompose remaining low-risk ALL policies and merge SELECT overlaps.
-- Scope: client_flag_assessments, exercises, client_match_preferences, provider_match_preferences

-- client_flag_assessments
drop policy if exists "clinicians_write_client_flags" on public.client_flag_assessments;

create policy "clinicians_insert_client_flags"
  on public.client_flag_assessments
  as permissive
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from encounters e
      join organization_members om on om.organization_id = e.organization_id
      where (
        e.id = client_flag_assessments.encounter_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );

create policy "clinicians_update_client_flags"
  on public.client_flag_assessments
  as permissive
  for update
  to authenticated
  using (
    exists (
      select 1
      from encounters e
      join organization_members om on om.organization_id = e.organization_id
      where (
        e.id = client_flag_assessments.encounter_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  )
  with check (
    exists (
      select 1
      from encounters e
      join organization_members om on om.organization_id = e.organization_id
      where (
        e.id = client_flag_assessments.encounter_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );

create policy "clinicians_delete_client_flags"
  on public.client_flag_assessments
  as permissive
  for delete
  to authenticated
  using (
    exists (
      select 1
      from encounters e
      join organization_members om on om.organization_id = e.organization_id
      where (
        e.id = client_flag_assessments.encounter_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );

-- exercises
drop policy if exists "admin_write_exercises" on public.exercises;

create policy "admin_insert_exercises"
  on public.exercises
  as permissive
  for insert
  to public
  with check (is_platform_admin());

create policy "admin_update_exercises"
  on public.exercises
  as permissive
  for update
  to public
  using (is_platform_admin())
  with check (is_platform_admin());

create policy "admin_delete_exercises"
  on public.exercises
  as permissive
  for delete
  to public
  using (is_platform_admin());

-- client_match_preferences
drop policy if exists "client can manage own match prefs" on public.client_match_preferences;
drop policy if exists "org members can read client match prefs" on public.client_match_preferences;

create policy "client_match_preferences_insert_own"
  on public.client_match_preferences
  as permissive
  for insert
  to public
  with check (client_person_id = get_my_person_id());

create policy "client_match_preferences_update_own"
  on public.client_match_preferences
  as permissive
  for update
  to public
  using (client_person_id = get_my_person_id())
  with check (client_person_id = get_my_person_id());

create policy "client_match_preferences_delete_own"
  on public.client_match_preferences
  as permissive
  for delete
  to public
  using (client_person_id = get_my_person_id());

create policy "client_match_preferences_select_consolidated"
  on public.client_match_preferences
  as permissive
  for select
  to public
  using (
    client_person_id = get_my_person_id()
    or organization_id is null
    or is_org_member(organization_id)
  );

-- provider_match_preferences
drop policy if exists "provider can manage own prefs" on public.provider_match_preferences;
drop policy if exists "org members can read provider match prefs" on public.provider_match_preferences;

create policy "provider_match_preferences_insert_own"
  on public.provider_match_preferences
  as permissive
  for insert
  to public
  with check (provider_person_id = get_my_person_id());

create policy "provider_match_preferences_update_own"
  on public.provider_match_preferences
  as permissive
  for update
  to public
  using (provider_person_id = get_my_person_id())
  with check (provider_person_id = get_my_person_id());

create policy "provider_match_preferences_delete_own"
  on public.provider_match_preferences
  as permissive
  for delete
  to public
  using (provider_person_id = get_my_person_id());

create policy "provider_match_preferences_select_consolidated"
  on public.provider_match_preferences
  as permissive
  for select
  to public
  using (
    provider_person_id = get_my_person_id()
    or is_org_member(organization_id)
  );;
