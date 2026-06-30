-- P0 hardening: remove broad write access from service-only tables
-- Source:
--   - Supabase advisor `rls_policy_always_true`
--   - Supabase docs recommend specifying roles in policies and restricting
--     table-level grants alongside RLS.
--
-- Design:
--   - `patient_clinical_state` writes are service-role only in current app code
--   - `referral_link_events` inserts are service-role only in current app code
--   - keep authenticated read paths
--   - remove anon access and broad write grants
--   - remove always-true insert/update policies that are no longer needed

-- ---------------------------------------------------------------------------
-- patient_clinical_state
-- ---------------------------------------------------------------------------

revoke all on table public.patient_clinical_state from anon;
revoke all on table public.patient_clinical_state from authenticated;
grant select on table public.patient_clinical_state to authenticated;
drop policy if exists patient_state_insert_service on public.patient_clinical_state;
drop policy if exists patient_state_update_service on public.patient_clinical_state;
drop policy if exists patient_state_select_org_member on public.patient_clinical_state;
create policy patient_state_select_org_member
  on public.patient_clinical_state
  for select
  to authenticated
  using (is_org_member(organization_id));
-- ---------------------------------------------------------------------------
-- referral_link_events
-- ---------------------------------------------------------------------------

revoke all on table public.referral_link_events from anon;
revoke all on table public.referral_link_events from authenticated;
grant select on table public.referral_link_events to authenticated;
drop policy if exists service_insert_events on public.referral_link_events;
drop policy if exists provider_read_link_events on public.referral_link_events;
create policy provider_read_link_events
  on public.referral_link_events
  for select
  to authenticated
  using (
    link_id in (
      select provider_referral_links.id
      from public.provider_referral_links
      where provider_referral_links.provider_person_id = get_my_person_id()
    )
  );
