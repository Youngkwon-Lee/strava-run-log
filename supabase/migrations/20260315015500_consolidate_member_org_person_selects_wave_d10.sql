-- Wave D10: consolidate inherited SELECT overlaps on members/orgs/persons.

-- organization_members
drop policy if exists "members_view_org_colleagues" on public.organization_members;
drop policy if exists "organization_members_select_own_authenticated" on public.organization_members;
create policy "organization_members_select_consolidated"
  on public.organization_members
  as permissive
  for select
  to authenticated
  using (
    person_id = get_my_person_id()
    or organization_id in (
      select get_my_org_ids_internal.organization_id
      from get_my_org_ids_internal() get_my_org_ids_internal(organization_id)
    )
  );
-- organizations
drop policy if exists "organizations_member_select" on public.organizations;
drop policy if exists "organizations_platform_admin" on public.organizations;
create policy "organizations_select_consolidated"
  on public.organizations
  as permissive
  for select
  to authenticated
  using (
    is_platform_admin()
    or id in (
      select get_my_org_ids_internal.organization_id
      from get_my_org_ids_internal() get_my_org_ids_internal(organization_id)
    )
    or id in (
      select organization_members.organization_id
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.status = 'active'::text
        and organization_members.deleted_at is null
      )
    )
  );
-- persons
drop policy if exists "org_members_view_colleagues" on public.persons;
