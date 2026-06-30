-- Fix residual INSERT overlap on care_relationship (public role).

drop policy if exists "care_rel_admin_insert" on public.care_relationship;
drop policy if exists "care_rel_provider_write" on public.care_relationship;

create policy "care_rel_insert_admin_or_provider"
  on public.care_relationship
  as permissive
  for insert
  to public
  with check (
    is_org_admin(organization_id)
    or (
      provider_person_id = get_my_person_id()
      and is_org_member(organization_id)
    )
  );;
