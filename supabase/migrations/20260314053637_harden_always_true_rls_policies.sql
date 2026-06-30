drop policy if exists patient_state_insert_service on public.patient_clinical_state;
create policy patient_state_insert_service
  on public.patient_clinical_state
  for insert
  to service_role
  with check (auth.role() = 'service_role');

drop policy if exists patient_state_update_service on public.patient_clinical_state;
create policy patient_state_update_service
  on public.patient_clinical_state
  for update
  to service_role
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

drop policy if exists service_insert_events on public.referral_link_events;
create policy service_insert_events
  on public.referral_link_events
  for insert
  to service_role
  with check (auth.role() = 'service_role');;
