-- Wave C: consolidate high-signal duplicate permissive policies.
-- Strategy: keep SELECT policies explicit and split ALL admin/owner policies into I/U/D.

-- recommendations (SELECT): merge client + org-member read into one policy.
drop policy if exists "clients_select_own_recommendations" on public.recommendations;
drop policy if exists "org_members_select_recommendations" on public.recommendations;
create policy "recommendations_select_client_or_org_member"
  on public.recommendations
  as permissive
  for select
  to public
  using ((subject_person_id = get_my_person_id()) or is_org_member(organization_id));
-- provider_referral_links: split ALL owner policy and merge SELECT visibility.
drop policy if exists "provider_own_links" on public.provider_referral_links;
drop policy if exists "public_read_active_links" on public.provider_referral_links;
create policy "provider_referral_links_select_visible"
  on public.provider_referral_links
  as permissive
  for select
  to public
  using ((is_active = true) or (provider_person_id = get_my_person_id()));
create policy "provider_referral_links_insert_own"
  on public.provider_referral_links
  as permissive
  for insert
  to public
  with check (provider_person_id = get_my_person_id());
create policy "provider_referral_links_update_own"
  on public.provider_referral_links
  as permissive
  for update
  to public
  using (provider_person_id = get_my_person_id())
  with check (provider_person_id = get_my_person_id());
create policy "provider_referral_links_delete_own"
  on public.provider_referral_links
  as permissive
  for delete
  to public
  using (provider_person_id = get_my_person_id());
-- rate_plans: split ALL admin policy into I/U/D.
drop policy if exists "rate_plans_admin_write" on public.rate_plans;
create policy "rate_plans_admin_insert"
  on public.rate_plans
  as permissive
  for insert
  to public
  with check (is_org_admin(organization_id));
create policy "rate_plans_admin_update"
  on public.rate_plans
  as permissive
  for update
  to public
  using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));
create policy "rate_plans_admin_delete"
  on public.rate_plans
  as permissive
  for delete
  to public
  using (is_org_admin(organization_id));
-- person_outcomes: split ALL admin policy into I/U/D.
drop policy if exists "client_outcomes_admin_write" on public.person_outcomes;
create policy "client_outcomes_admin_insert"
  on public.person_outcomes
  as permissive
  for insert
  to public
  with check (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = person_outcomes.organization_id
        and om.person_id = (
          select persons.id
          from persons
          where persons.auth_user_id = (select auth.uid())
        )
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );
create policy "client_outcomes_admin_update"
  on public.person_outcomes
  as permissive
  for update
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = person_outcomes.organization_id
        and om.person_id = (
          select persons.id
          from persons
          where persons.auth_user_id = (select auth.uid())
        )
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  )
  with check (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = person_outcomes.organization_id
        and om.person_id = (
          select persons.id
          from persons
          where persons.auth_user_id = (select auth.uid())
        )
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );
create policy "client_outcomes_admin_delete"
  on public.person_outcomes
  as permissive
  for delete
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.organization_id = person_outcomes.organization_id
        and om.person_id = (
          select persons.id
          from persons
          where persons.auth_user_id = (select auth.uid())
        )
        and om.role = any (array['owner'::text, 'admin'::text])
      )
    )
  );
-- org_provider_profile: split ALL admin policy into I/U/D.
drop policy if exists "provider_profile_admin_write" on public.org_provider_profile;
create policy "provider_profile_admin_insert"
  on public.org_provider_profile
  as permissive
  for insert
  to public
  with check (is_org_admin(organization_id));
create policy "provider_profile_admin_update"
  on public.org_provider_profile
  as permissive
  for update
  to public
  using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));
create policy "provider_profile_admin_delete"
  on public.org_provider_profile
  as permissive
  for delete
  to public
  using (is_org_admin(organization_id));
