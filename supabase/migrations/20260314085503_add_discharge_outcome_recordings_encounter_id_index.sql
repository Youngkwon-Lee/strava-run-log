-- P1 follow-up: add covering index for discharge_outcome_recordings foreign key.

create index if not exists idx_discharge_outcome_recordings_encounter_id
  on public.discharge_outcome_recordings (encounter_id);;
