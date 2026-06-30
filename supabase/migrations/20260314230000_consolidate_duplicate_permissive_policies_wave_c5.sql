-- Wave C5: close remaining duplicate permissive role/action pairs.

-- approach_exercise_bundles: keep single public SELECT policy.
drop policy if exists "aeb_read_policy" on public.approach_exercise_bundles;
-- approach_treatment_bundles: keep single public SELECT policy.
drop policy if exists "atb_read_policy" on public.approach_treatment_bundles;
-- audit_logs: merge duplicate SELECT policies.
drop policy if exists "audit_logs_org_admin_view" on public.audit_logs;
drop policy if exists "audit_logs_self_view" on public.audit_logs;
create policy "audit_logs_select_consolidated"
  on public.audit_logs
  as permissive
  for select
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = audit_logs.organization_id
        and om.person_id = (
          select persons.id
          from persons
          where persons.auth_user_id = (select auth.uid())
        )
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
    or (
      actor_person_id = (
        select persons.id
        from persons
        where persons.auth_user_id = (select auth.uid())
      )
    )
  );
-- bookings: remove UPDATE overlap and normalize admin ALL policy into explicit actions.
drop policy if exists "bookings_admin_all" on public.bookings;
drop policy if exists "bookings_subject_insert" on public.bookings;
drop policy if exists "bookings_provider_update" on public.bookings;
drop policy if exists "bookings_subject_update" on public.bookings;
create policy "bookings_insert_admin_or_subject"
  on public.bookings
  as permissive
  for insert
  to public
  with check (
    exists (
      select 1
      from (
        organization_members om
        join persons p on p.id = om.person_id
      )
      where (
        p.auth_user_id = (select auth.uid())
        and om.organization_id = bookings.organization_id
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
    or (
      subject_person_id = (
        select p.id
        from persons p
        where p.auth_user_id = (select auth.uid())
        limit 1
      )
    )
  );
create policy "bookings_update_admin_or_provider_or_subject"
  on public.bookings
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from (
        organization_members om
        join persons p on p.id = om.person_id
      )
      where (
        p.auth_user_id = (select auth.uid())
        and om.organization_id = bookings.organization_id
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
    or (
      provider_person_id = (
        select p.id
        from persons p
        where p.auth_user_id = (select auth.uid())
        limit 1
      )
    )
    or (
      subject_person_id = (
        select p.id
        from persons p
        where p.auth_user_id = (select auth.uid())
        limit 1
      )
      and status = any (array['pending'::text, 'confirmed'::text])
    )
  )
  with check (
    exists (
      select 1
      from (
        organization_members om
        join persons p on p.id = om.person_id
      )
      where (
        p.auth_user_id = (select auth.uid())
        and om.organization_id = bookings.organization_id
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
    or (
      provider_person_id = (
        select p.id
        from persons p
        where p.auth_user_id = (select auth.uid())
        limit 1
      )
    )
    or (
      subject_person_id = (
        select p.id
        from persons p
        where p.auth_user_id = (select auth.uid())
        limit 1
      )
    )
  );
create policy "bookings_delete_admin"
  on public.bookings
  as permissive
  for delete
  to public
  using (
    exists (
      select 1
      from (
        organization_members om
        join persons p on p.id = om.person_id
      )
      where (
        p.auth_user_id = (select auth.uid())
        and om.organization_id = bookings.organization_id
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );
-- data_sharing_consent: merge duplicated ALL policies.
drop policy if exists "sharing_admin_manage" on public.data_sharing_consent;
drop policy if exists "sharing_self_manage" on public.data_sharing_consent;
create policy "sharing_manage_admin_or_self"
  on public.data_sharing_consent
  as permissive
  for all
  to public
  using (is_org_admin(from_org_id) or (subject_person_id = get_my_person_id()))
  with check (is_org_admin(from_org_id) or (subject_person_id = get_my_person_id()));
-- exercises: merge duplicated public SELECT policies.
drop policy if exists "Clients can view exercises" on public.exercises;
drop policy if exists "authenticated_read_exercises" on public.exercises;
create policy "exercises_client_or_authenticated_read"
  on public.exercises
  as permissive
  for select
  to public
  using (
    (((select auth.jwt()) ->> 'app_role'::text) = 'client'::text)
    or ((select auth.role()) = 'authenticated'::text)
  );
-- ml_model_registry: merge duplicated ALL policies.
drop policy if exists "ml_registry_manage_admin" on public.ml_model_registry;
drop policy if exists "ml_registry_platform_admin" on public.ml_model_registry;
create policy "ml_registry_manage_admin_or_platform"
  on public.ml_model_registry
  as permissive
  for all
  to public
  using (is_org_admin(organization_id) or is_platform_admin())
  with check (is_org_admin(organization_id) or is_platform_admin());
-- observations: split admin ALL and merge SELECT policies.
drop policy if exists "observations_admin_access" on public.observations;
drop policy if exists "observations_client_access" on public.observations;
drop policy if exists "observations_provider_access" on public.observations;
create policy "observations_admin_insert"
  on public.observations
  as permissive
  for insert
  to public
  with check (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = observations.organization_id
      )
    )
  );
create policy "observations_admin_update"
  on public.observations
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = observations.organization_id
      )
    )
  )
  with check (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = observations.organization_id
      )
    )
  );
create policy "observations_admin_delete"
  on public.observations
  as permissive
  for delete
  to public
  using (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = observations.organization_id
      )
    )
  );
create policy "observations_select_consolidated"
  on public.observations
  as permissive
  for select
  to public
  using (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = observations.organization_id
      )
    )
    or (subject_person_id = get_my_person_id())
    or (
      (
        encounter_id is not null
        and exists (
          select 1
          from (
            encounters e
            join organization_members om on om.organization_id = e.organization_id
          )
          where (
            e.id = observations.encounter_id
            and om.person_id = get_my_person_id()
            and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
            and om.status = 'active'::text
          )
        )
      )
      or (
        encounter_id is null
        and exists (
          select 1
          from organization_members om
          where (
            om.organization_id = observations.organization_id
            and om.person_id = get_my_person_id()
            and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
            and om.status = 'active'::text
          )
        )
      )
    )
  );
-- org_caregiver_link: split admin ALL and merge SELECT policies.
drop policy if exists "caregiver_admin_write" on public.org_caregiver_link;
drop policy if exists "caregiver_org_read" on public.org_caregiver_link;
drop policy if exists "caregiver_self_read" on public.org_caregiver_link;
create policy "caregiver_admin_insert"
  on public.org_caregiver_link
  as permissive
  for insert
  to public
  with check (is_org_admin(organization_id));
create policy "caregiver_admin_update"
  on public.org_caregiver_link
  as permissive
  for update
  to public
  using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));
create policy "caregiver_admin_delete"
  on public.org_caregiver_link
  as permissive
  for delete
  to public
  using (is_org_admin(organization_id));
create policy "caregiver_org_or_self_read"
  on public.org_caregiver_link
  as permissive
  for select
  to public
  using (
    is_org_member(organization_id)
    or (caregiver_person_id = get_my_person_id())
    or (client_person_id = get_my_person_id())
  );
-- organization_members: merge duplicated authenticated SELECT policies.
drop policy if exists "org_members_select_own" on public.organization_members;
drop policy if exists "users_view_own_memberships" on public.organization_members;
create policy "organization_members_select_own_authenticated"
  on public.organization_members
  as permissive
  for select
  to authenticated
  using (person_id = get_my_person_id());
-- persons: remove redundant public self-access SELECT policy.
drop policy if exists "persons_self_access" on public.persons;
-- procedures: split admin ALL and merge SELECT policies.
drop policy if exists "procedures_admin_access" on public.procedures;
drop policy if exists "procedures_client_access" on public.procedures;
drop policy if exists "procedures_provider_access" on public.procedures;
create policy "procedures_admin_insert"
  on public.procedures
  as permissive
  for insert
  to public
  with check (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = procedures.organization_id
      )
    )
  );
create policy "procedures_admin_update"
  on public.procedures
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = procedures.organization_id
      )
    )
  )
  with check (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = procedures.organization_id
      )
    )
  );
create policy "procedures_admin_delete"
  on public.procedures
  as permissive
  for delete
  to public
  using (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = procedures.organization_id
      )
    )
  );
create policy "procedures_select_consolidated"
  on public.procedures
  as permissive
  for select
  to public
  using (
    exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = procedures.organization_id
      )
    )
    or (subject_person_id = get_my_person_id())
    or exists (
      select 1
      from (
        encounters e
        join organization_members om on om.organization_id = e.organization_id
      )
      where (
        e.id = procedures.encounter_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
        and om.status = 'active'::text
      )
    )
  );
