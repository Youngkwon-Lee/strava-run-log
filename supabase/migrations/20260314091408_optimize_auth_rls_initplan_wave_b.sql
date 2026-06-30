-- Wave B: optimize RLS policies to avoid per-row auth/current_setting re-evaluation.

alter policy "service role can update review_status"
  on public.ai_inference_log
  using (((select auth.role()) = 'service_role'::text))
  with check (((select auth.role()) = 'service_role'::text));

alter policy "Clients can view exercises"
  on public.exercises
  using ((((select auth.jwt()) ->> 'app_role'::text) = 'client'::text));

alter policy "observations_clinician_insert"
  on public.observations
  with check (
    (exists (
      select 1
      from organization_members om
      where (
        om.person_id = (
          select p.id
          from persons p
          where p.auth_user_id = (select auth.uid())
        )
        and om.organization_id = observations.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    ))
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
      or (encounter_id is null and activity_session_id is not null)
    )
  );

alter policy "observations_clinician_update"
  on public.observations
  using (
    exists (
      select 1
      from organization_members om
      where (
        om.person_id = (
          select p.id
          from persons p
          where p.auth_user_id = (select auth.uid())
        )
        and om.organization_id = observations.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    )
  )
  with check (
    (exists (
      select 1
      from organization_members om
      where (
        om.person_id = (
          select p.id
          from persons p
          where p.auth_user_id = (select auth.uid())
        )
        and om.organization_id = observations.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
      )
    ))
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
      or (encounter_id is null and activity_session_id is not null)
    )
  );

alter policy "auth_users_insert_organizations"
  on public.organizations
  with check (((select auth.role()) = 'authenticated'::text));

alter policy "patient_state_insert_service"
  on public.patient_clinical_state
  with check (((select auth.role()) = 'service_role'::text));

alter policy "patient_state_update_service"
  on public.patient_clinical_state
  using (((select auth.role()) = 'service_role'::text))
  with check (((select auth.role()) = 'service_role'::text));

alter policy "persons_org_colleagues_optimized"
  on public.persons
  using (
    (auth_user_id = (select auth.uid()))
    or exists (
      select 1
      from (
        organization_members om_requester
        join organization_members om_target
          on om_target.organization_id = om_requester.organization_id
      )
      where (
        om_requester.person_id = get_my_person_id()
        and om_requester.status = 'active'::text
        and om_requester.deleted_at is null
        and om_target.person_id = persons.id
        and om_target.status = 'active'::text
        and om_target.deleted_at is null
      )
    )
    or can_access_client_via_org(id)
  );

alter policy "recommendation_learning_log_read"
  on public.recommendation_learning_log
  using (((select auth.role()) = 'authenticated'::text));

alter policy "service_insert_events"
  on public.referral_link_events
  with check (((select auth.role()) = 'service_role'::text));;
