-- Wave C3: reduce duplicate permissive policies on core clinical/activity tables.

-- activity_sessions: merge duplicate SELECT policies
drop policy if exists "activity_sessions_client_select" on public.activity_sessions;
drop policy if exists "activity_sessions_provider_select" on public.activity_sessions;
create policy "activity_sessions_client_or_provider_select"
  on public.activity_sessions
  as permissive
  for select
  to public
  using (
    (subject_person_id = get_my_person_id())
    or (
      (organization_id is not null)
      and exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = activity_sessions.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
          and om.status = 'active'::text
        )
      )
    )
  );

-- care_plans: split ALL author policy + merge SELECT policies
drop policy if exists "care_plans_author_access" on public.care_plans;
drop policy if exists "care_plans_client_access" on public.care_plans;
drop policy if exists "care_plans_org_member_access" on public.care_plans;

create policy "care_plans_author_insert"
  on public.care_plans
  as permissive
  for insert
  to public
  with check (
    author_id in (
      select persons.id
      from persons
      where persons.auth_user_id = (select auth.uid())
    )
  );

create policy "care_plans_author_update"
  on public.care_plans
  as permissive
  for update
  to public
  using (
    author_id in (
      select persons.id
      from persons
      where persons.auth_user_id = (select auth.uid())
    )
  )
  with check (
    author_id in (
      select persons.id
      from persons
      where persons.auth_user_id = (select auth.uid())
    )
  );

create policy "care_plans_author_delete"
  on public.care_plans
  as permissive
  for delete
  to public
  using (
    author_id in (
      select persons.id
      from persons
      where persons.auth_user_id = (select auth.uid())
    )
  );

create policy "care_plans_client_or_org_select"
  on public.care_plans
  as permissive
  for select
  to public
  using (
    (subject_person_id = get_my_person_id())
    or exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = care_plans.organization_id
        and om.status = 'active'::text
      )
    )
  );

-- care_relationship: split ALL admin + merge SELECT
drop policy if exists "care_rel_admin_write" on public.care_relationship;
drop policy if exists "care_rel_org_read" on public.care_relationship;
drop policy if exists "care_rel_self_read" on public.care_relationship;

create policy "care_rel_admin_insert"
  on public.care_relationship
  as permissive
  for insert
  to public
  with check (is_org_admin(organization_id));

create policy "care_rel_admin_update"
  on public.care_relationship
  as permissive
  for update
  to public
  using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));

create policy "care_rel_admin_delete"
  on public.care_relationship
  as permissive
  for delete
  to public
  using (is_org_admin(organization_id));

create policy "care_rel_org_or_self_read"
  on public.care_relationship
  as permissive
  for select
  to public
  using (
    is_org_member(organization_id)
    or (client_person_id = get_my_person_id())
    or (provider_person_id = get_my_person_id())
  );

-- encounter_media: merge duplicate SELECT
drop policy if exists "encounter_media_client_read" on public.encounter_media;
drop policy if exists "encounter_media_org_read" on public.encounter_media;
create policy "encounter_media_client_or_org_read"
  on public.encounter_media
  as permissive
  for select
  to public
  using (
    (deleted_at is null)
    and (
      (subject_person_id = get_my_person_id())
      or exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = encounter_media.organization_id
          and om.status = 'active'::text
        )
      )
    )
  );

-- exercise_prescriptions: merge duplicate SELECT
drop policy if exists "ep_client_read" on public.exercise_prescriptions;
drop policy if exists "ep_org_read" on public.exercise_prescriptions;
create policy "ep_client_or_org_read"
  on public.exercise_prescriptions
  as permissive
  for select
  to public
  using (
    (subject_person_id = get_my_person_id())
    or exists (
      select 1
      from organization_members om
      where (
        om.organization_id = exercise_prescriptions.organization_id
        and om.person_id = get_my_person_id()
        and om.status = 'active'::text
      )
    )
  );

-- exercise_programs: merge duplicate SELECT
drop policy if exists "epr_client_read" on public.exercise_programs;
drop policy if exists "epr_org_read" on public.exercise_programs;
create policy "epr_client_or_org_read"
  on public.exercise_programs
  as permissive
  for select
  to public
  using (
    (subject_person_id = get_my_person_id())
    or exists (
      select 1
      from organization_members om
      where (
        om.organization_id = exercise_programs.organization_id
        and om.person_id = get_my_person_id()
        and om.status = 'active'::text
      )
    )
  );

-- goals: merge duplicate SELECT
drop policy if exists "goals_client_select" on public.goals;
drop policy if exists "goals_staff_select" on public.goals;
create policy "goals_client_or_staff_select"
  on public.goals
  as permissive
  for select
  to public
  using (
    (subject_person_id = get_my_person_id())
    or exists (
      select 1
      from organization_members om
      where (
        om.organization_id = goals.organization_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
        and om.status = 'active'::text
      )
    )
  );

-- match_results: split ALL admin + merge SELECT
drop policy if exists "org admin can manage match results" on public.match_results;
drop policy if exists "client can view own match results" on public.match_results;
drop policy if exists "provider can view own match results" on public.match_results;

create policy "match_results_org_admin_insert"
  on public.match_results
  as permissive
  for insert
  to public
  with check ((organization_id is not null) and is_org_admin(organization_id));

create policy "match_results_org_admin_update"
  on public.match_results
  as permissive
  for update
  to public
  using ((organization_id is not null) and is_org_admin(organization_id))
  with check ((organization_id is not null) and is_org_admin(organization_id));

create policy "match_results_org_admin_delete"
  on public.match_results
  as permissive
  for delete
  to public
  using ((organization_id is not null) and is_org_admin(organization_id));

create policy "match_results_client_or_provider_select"
  on public.match_results
  as permissive
  for select
  to public
  using (
    (client_person_id = get_my_person_id())
    or (provider_person_id = get_my_person_id())
  );

-- medication_statements: split ALL provider + merge SELECT
drop policy if exists "medication_statements_provider_write" on public.medication_statements;
drop policy if exists "medication_statements_client_read" on public.medication_statements;
drop policy if exists "medication_statements_org_read" on public.medication_statements;

create policy "medication_statements_provider_insert"
  on public.medication_statements
  as permissive
  for insert
  to public
  with check (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = medication_statements.organization_id
        and om.status = 'active'::text
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );

create policy "medication_statements_provider_update"
  on public.medication_statements
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = medication_statements.organization_id
        and om.status = 'active'::text
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  )
  with check (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = medication_statements.organization_id
        and om.status = 'active'::text
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );

create policy "medication_statements_provider_delete"
  on public.medication_statements
  as permissive
  for delete
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = medication_statements.organization_id
        and om.status = 'active'::text
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  );

create policy "medication_statements_client_or_org_read"
  on public.medication_statements
  as permissive
  for select
  to public
  using (
    (subject_person_id = get_my_person_id())
    or exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = medication_statements.organization_id
        and om.status = 'active'::text
      )
    )
  );

-- pghd_observations: merge duplicate SELECT
drop policy if exists "pghd_clinician_read" on public.pghd_observations;
drop policy if exists "pghd_self_read" on public.pghd_observations;
create policy "pghd_observations_clinician_or_self_read"
  on public.pghd_observations
  as permissive
  for select
  to public
  using (
    can_access_client_via_org(person_id)
    or (person_id = get_my_person_id())
  );;
