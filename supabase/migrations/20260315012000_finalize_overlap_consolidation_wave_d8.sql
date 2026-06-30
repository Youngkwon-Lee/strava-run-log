-- Wave D8: finalize overlap consolidation with semantics-preserving OR unions.
-- Scope: feature_flag_logs, leads, person_events

-- feature_flag_logs
drop policy if exists "org_member_access" on public.feature_flag_logs;
drop policy if exists "ffl_insert" on public.feature_flag_logs;
drop policy if exists "ffl_select" on public.feature_flag_logs;
create policy "feature_flag_logs_insert_consolidated"
  on public.feature_flag_logs
  as permissive
  for insert
  to public
  with check (
    organization_id is null
    or is_org_member(organization_id)
    or (select auth.role()) = 'authenticated'
  );
create policy "feature_flag_logs_select_consolidated"
  on public.feature_flag_logs
  as permissive
  for select
  to public
  using (
    organization_id is null
    or is_org_member(organization_id)
    or exists (
      select 1
      from platform_admins pa
      where (pa.person_id = get_my_person_id() and pa.is_active = true)
    )
  );
create policy "feature_flag_logs_update_org_member"
  on public.feature_flag_logs
  as permissive
  for update
  to public
  using (
    organization_id is null
    or is_org_member(organization_id)
  )
  with check (
    organization_id is null
    or is_org_member(organization_id)
  );
create policy "feature_flag_logs_delete_org_member"
  on public.feature_flag_logs
  as permissive
  for delete
  to public
  using (
    organization_id is null
    or is_org_member(organization_id)
  );
-- leads
drop policy if exists "leads_org_write" on public.leads;
drop policy if exists "leads_org_read" on public.leads;
create policy "leads_insert_org_write"
  on public.leads
  as permissive
  for insert
  to public
  with check (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = leads.organization_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'staff'::text])
      )
    )
  );
create policy "leads_update_org_write"
  on public.leads
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = leads.organization_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'staff'::text])
      )
    )
  )
  with check (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = leads.organization_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'staff'::text])
      )
    )
  );
create policy "leads_delete_org_write"
  on public.leads
  as permissive
  for delete
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = leads.organization_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'staff'::text])
      )
    )
  );
create policy "leads_select_consolidated"
  on public.leads
  as permissive
  for select
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = leads.organization_id
        and om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'staff'::text])
      )
    )
    or (
      deleted_at is null
      and exists (
        select 1
        from organization_members om
        where (
          om.organization_id = leads.organization_id
          and om.person_id = get_my_person_id()
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
        )
      )
    )
  );
-- person_events
drop policy if exists "org_member_access" on public.person_events;
drop policy if exists "person_events_insert_admin" on public.person_events;
drop policy if exists "person_events_read_own_or_org" on public.person_events;
create policy "person_events_insert_consolidated"
  on public.person_events
  as permissive
  for insert
  to public
  with check (
    organization_id is null
    or is_org_member(organization_id)
    or exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.role = any (array['owner'::text, 'admin'::text, 'staff'::text])
      )
    )
  );
create policy "person_events_select_consolidated"
  on public.person_events
  as permissive
  for select
  to public
  using (
    organization_id is null
    or is_org_member(organization_id)
    or person_id = get_my_person_id()
    or exists (
      select 1
      from organization_members om1
      where (
        om1.person_id = get_my_person_id()
        and om1.organization_id in (
          select om2.organization_id
          from organization_members om2
          where om2.person_id = person_events.person_id
        )
        and om1.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
  );
create policy "person_events_update_org_member"
  on public.person_events
  as permissive
  for update
  to public
  using (
    organization_id is null
    or is_org_member(organization_id)
  )
  with check (
    organization_id is null
    or is_org_member(organization_id)
  );
create policy "person_events_delete_org_member"
  on public.person_events
  as permissive
  for delete
  to public
  using (
    organization_id is null
    or is_org_member(organization_id)
  );
