-- Wave C4: consolidate remaining duplicate permissive SELECT policies.

-- assessment_form_responses: merge 4 SELECT policies into one.
drop policy if exists "afr_clinician_read_self_report" on public.assessment_form_responses;
drop policy if exists "afr_clinician_select_direct" on public.assessment_form_responses;
drop policy if exists "afr_matched_provider_select" on public.assessment_form_responses;
drop policy if exists "afr_member_select" on public.assessment_form_responses;
create policy "afr_select_consolidated"
  on public.assessment_form_responses
  as permissive
  for select
  to public
  using (
    (
      (source_type)::text = 'patient_self_report'::text
      and exists (
        select 1
        from (
          org_clients op
          join organization_members om on om.organization_id = op.organization_id
        )
        where (
          op.person_id = assessment_form_responses.subject_person_id
          and om.person_id = get_my_person_id()
          and om.status = 'active'::text
        )
      )
    )
    or exists (
      select 1
      from organization_members om
      where (
        om.organization_id = assessment_form_responses.organization_id
        and om.person_id = get_my_person_id()
        and om.status = 'active'::text
      )
    )
    or exists (
      select 1
      from match_results mr
      where (
        mr.client_person_id = assessment_form_responses.subject_person_id
        and mr.provider_person_id = get_my_person_id()
        and mr.status = 'accepted'::text
      )
    )
    or exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = assessment_form_responses.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
  );
-- booking_events: merge 3 SELECT policies into one.
drop policy if exists "booking_events_org_staff_select" on public.booking_events;
drop policy if exists "booking_events_person_select" on public.booking_events;
drop policy if exists "booking_events_professional_select" on public.booking_events;
create policy "booking_events_select_consolidated"
  on public.booking_events
  as permissive
  for select
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = booking_events.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
    or exists (
      select 1
      from bookings b
      where (
        b.id = booking_events.booking_id
        and b.subject_person_id = (
          select p.id
          from persons p
          where p.auth_user_id = (select auth.uid())
          limit 1
        )
      )
    )
    or exists (
      select 1
      from bookings b
      where (
        b.id = booking_events.booking_id
        and b.provider_person_id = (
          select p.id
          from persons p
          where p.auth_user_id = (select auth.uid())
          limit 1
        )
      )
    )
  );
-- bookings: merge 3 SELECT policies into one.
drop policy if exists "bookings_org_staff_select" on public.bookings;
drop policy if exists "bookings_provider_select" on public.bookings;
drop policy if exists "bookings_subject_select" on public.bookings;
create policy "bookings_select_consolidated"
  on public.bookings
  as permissive
  for select
  to public
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = get_my_person_id()
        and om.organization_id = bookings.organization_id
        and om.role = any (array['provider'::text, 'staff'::text])
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
-- conversations: merge 3 SELECT policies into one.
drop policy if exists "conv_client_select" on public.conversations;
drop policy if exists "conv_org_member_select" on public.conversations;
drop policy if exists "conv_professional_select" on public.conversations;
create policy "conversations_select_consolidated"
  on public.conversations
  as permissive
  for select
  to public
  using (
    client_person_id = (
      select persons.id
      from persons
      where persons.auth_user_id = (select auth.uid())
    )
    or exists (
      select 1
      from organization_members om
      where (
        om.person_id = (
          select persons.id
          from persons
          where persons.auth_user_id = (select auth.uid())
        )
        and om.organization_id = conversations.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
    or professional_person_id = (
      select persons.id
      from persons
      where persons.auth_user_id = (select auth.uid())
    )
  );
-- data_sharing_consent: merge 3 SELECT policies into one.
drop policy if exists "sharing_from_org_read" on public.data_sharing_consent;
drop policy if exists "sharing_self_read" on public.data_sharing_consent;
drop policy if exists "sharing_to_org_read" on public.data_sharing_consent;
create policy "sharing_select_consolidated"
  on public.data_sharing_consent
  as permissive
  for select
  to public
  using (
    is_org_admin(from_org_id)
    or (subject_person_id = get_my_person_id())
    or is_org_admin(to_org_id)
  );
-- encounters: merge 3 SELECT policies into one.
drop policy if exists "encounters_admin_access" on public.encounters;
drop policy if exists "encounters_client_access" on public.encounters;
drop policy if exists "encounters_provider_access" on public.encounters;
create policy "encounters_select_consolidated"
  on public.encounters
  as permissive
  for select
  to public
  using (
    (deleted_at is null)
    and (
      exists (
        select 1
        from organization_members
        where (
          organization_members.person_id = get_my_person_id()
          and organization_members.role = any (array['owner'::text, 'admin'::text])
          and organization_members.organization_id = encounters.organization_id
          and organization_members.status = 'active'::text
        )
      )
      or (subject_person_id = get_my_person_id())
      or exists (
        select 1
        from organization_members om
        where (
          om.person_id = get_my_person_id()
          and om.organization_id = encounters.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
          and om.status = 'active'::text
        )
      )
    )
  );
-- episodes: merge 2 SELECT policies.
drop policy if exists "episodes_client_select" on public.episodes;
drop policy if exists "episodes_provider_select" on public.episodes;
create policy "episodes_select_consolidated"
  on public.episodes
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
          and om.organization_id = episodes.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
          and om.status = 'active'::text
        )
      )
    )
  );
-- chat_context_snapshots: merge 2 SELECT policies.
drop policy if exists "snapshots_client_select" on public.chat_context_snapshots;
drop policy if exists "snapshots_provider_select" on public.chat_context_snapshots;
create policy "snapshots_select_consolidated"
  on public.chat_context_snapshots
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
        and om.organization_id = chat_context_snapshots.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
        and om.status = 'active'::text
      )
    )
  );
-- clinical_events: merge 2 SELECT policies.
drop policy if exists "clinical_events_actor_read" on public.clinical_events;
drop policy if exists "clinical_events_admin_read" on public.clinical_events;
create policy "clinical_events_select_consolidated"
  on public.clinical_events
  as permissive
  for select
  to public
  using (
    (actor_id = get_my_person_id())
    or exists (
      select 1
      from organization_members
      where (
        organization_members.person_id = get_my_person_id()
        and organization_members.role = any (array['owner'::text, 'admin'::text])
        and organization_members.organization_id = clinical_events.organization_id
      )
    )
  );
-- clinical_insights: merge 2 SELECT policies.
drop policy if exists "read_clinical_insights_org_member" on public.clinical_insights;
drop policy if exists "read_clinical_insights_platform_admin" on public.clinical_insights;
create policy "clinical_insights_select_consolidated"
  on public.clinical_insights
  as permissive
  for select
  to public
  using (
    organization_id in (
      select organization_members.organization_id
      from organization_members
      where organization_members.person_id = get_my_person_id()
    )
    or is_platform_admin()
  );
-- conditions: merge 2 SELECT policies.
drop policy if exists "conditions_client_access" on public.conditions;
drop policy if exists "conditions_provider_access" on public.conditions;
create policy "conditions_select_consolidated"
  on public.conditions
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
        and om.organization_id = conditions.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
        and om.status = 'active'::text
      )
    )
  );
-- expert_bids: merge 2 SELECT policies.
drop policy if exists "expert_bids_client_select" on public.expert_bids;
drop policy if exists "expert_bids_expert_select" on public.expert_bids;
create policy "expert_bids_select_consolidated"
  on public.expert_bids
  as permissive
  for select
  to public
  using (
    (match_result_id in (
      select match_results.id
      from match_results
      where match_results.client_person_id = get_my_person_id()
    ))
    or (expert_person_id = get_my_person_id())
  );
