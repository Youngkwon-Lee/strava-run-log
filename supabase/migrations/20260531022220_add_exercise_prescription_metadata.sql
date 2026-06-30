alter table public.exercise_prescriptions
  add column if not exists metadata jsonb not null default '{}'::jsonb;
create index if not exists idx_exercise_prescriptions_metadata_gin
  on public.exercise_prescriptions using gin (metadata jsonb_path_ops);
