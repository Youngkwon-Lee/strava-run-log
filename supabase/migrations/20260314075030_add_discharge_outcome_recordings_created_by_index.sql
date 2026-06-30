-- P1 follow-up: add covering index for discharge_outcome_recordings foreign key.

create index if not exists idx_discharge_outcome_recordings_created_by
  on public.discharge_outcome_recordings (created_by);;
