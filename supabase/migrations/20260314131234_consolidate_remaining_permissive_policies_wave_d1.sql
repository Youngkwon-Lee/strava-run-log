-- Wave D1: consolidate remaining role/action duplicate permissive policies.
-- Scope: observations (INSERT/UPDATE), procedures (INSERT/UPDATE)

-- observations
drop policy if exists "observations_admin_insert" on public.observations;
drop policy if exists "observations_clinician_insert" on public.observations;
drop policy if exists "observations_admin_update" on public.observations;
drop policy if exists "observations_clinician_update" on public.observations;

create policy "observations_insert_consolidated"
  on public.observations
  as permissive
  for insert
  to public
  with check (
    (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = observations.organization_id
          and om.role = any (array['owner'::text, 'admin'::text])
        )
      )
    )
    or (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = observations.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
        )
      )
      and (
        (
          encounter_id is not null
          and exists (
            select 1
            from encounters e
            where (
              e.id = observations.encounter_id
              and e.organization_id = observations.organization_id
              and e.subject_person_id = observations.subject_person_id
            )
          )
        )
        or (
          encounter_id is null
          and activity_session_id is not null
        )
      )
    )
  );

create policy "observations_update_consolidated"
  on public.observations
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = observations.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  )
  with check (
    (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = observations.organization_id
          and om.role = any (array['owner'::text, 'admin'::text])
        )
      )
    )
    or (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = observations.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
        )
      )
      and (
        (
          encounter_id is not null
          and exists (
            select 1
            from encounters e
            where (
              e.id = observations.encounter_id
              and e.organization_id = observations.organization_id
              and e.subject_person_id = observations.subject_person_id
            )
          )
        )
        or (
          encounter_id is null
          and activity_session_id is not null
        )
      )
    )
  );

-- procedures
drop policy if exists "procedures_admin_insert" on public.procedures;
drop policy if exists "procedures_clinician_insert" on public.procedures;
drop policy if exists "procedures_admin_update" on public.procedures;
drop policy if exists "procedures_clinician_update" on public.procedures;

create policy "procedures_insert_consolidated"
  on public.procedures
  as permissive
  for insert
  to public
  with check (
    (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = procedures.organization_id
          and om.role = any (array['owner'::text, 'admin'::text])
        )
      )
    )
    or (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = procedures.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
        )
      )
      and (
        encounter_id is null
        or exists (
          select 1
          from encounters e
          where (
            e.id = procedures.encounter_id
            and e.organization_id = procedures.organization_id
          )
        )
      )
    )
  );

create policy "procedures_update_consolidated"
  on public.procedures
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = procedures.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  )
  with check (
    (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = procedures.organization_id
          and om.role = any (array['owner'::text, 'admin'::text])
        )
      )
    )
    or (
      exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = procedures.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
        )
      )
      and (
        encounter_id is null
        or exists (
          select 1
          from encounters e
          where (
            e.id = procedures.encounter_id
            and e.organization_id = procedures.organization_id
          )
        )
      )
    )
  );;
