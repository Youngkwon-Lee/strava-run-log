-- P1 follow-up: add covering index for patient_education_deliveries foreign key.

create index if not exists idx_patient_education_deliveries_person_id
  on public.patient_education_deliveries (person_id);
