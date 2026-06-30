-- Wave D11: consolidate remaining multiple permissive policies on assessment_form_responses.

drop policy if exists "afr_clinician_insert" on public.assessment_form_responses;
drop policy if exists "client_self_report_insert" on public.assessment_form_responses;
drop policy if exists "afr_select_consolidated" on public.assessment_form_responses;
drop policy if exists "client_self_report_select" on public.assessment_form_responses;
create policy "afr_insert_consolidated"
  on public.assessment_form_responses
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
          and om.organization_id = assessment_form_responses.organization_id
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
        )
      )
    )
    or (
      source_type::text = 'patient_self_report'::text
      and subject_person_id = get_my_person_id()
      and performer_person_id = subject_person_id
      and organization_id is null
    )
  );
create policy "afr_select_consolidated"
  on public.assessment_form_responses
  as permissive
  for select
  to public
  using (
    (
      source_type::text = 'patient_self_report'::text
      and exists (
        select 1
        from org_clients op
        join organization_members om on om.organization_id = op.organization_id
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
    or (
      source_type::text = 'patient_self_report'::text
      and subject_person_id = get_my_person_id()
    )
  );
