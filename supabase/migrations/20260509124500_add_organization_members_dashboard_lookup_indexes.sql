create index if not exists idx_org_members_person_active_joined_desc
  on public.organization_members (person_id, joined_at desc)
  where status = 'active' and deleted_at is null;
create index if not exists idx_org_members_person_org_active
  on public.organization_members (person_id, organization_id)
  where status = 'active' and deleted_at is null;
