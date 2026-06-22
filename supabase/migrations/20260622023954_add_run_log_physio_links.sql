alter table public.run_log_runs
  add column if not exists subject_person_id uuid,
  add column if not exists organization_id uuid,
  add column if not exists org_client_profile_id uuid,
  add column if not exists activity_session_id uuid,
  add column if not exists linked_at timestamptz;

create index if not exists run_log_runs_subject_person_start_date_idx
  on public.run_log_runs (subject_person_id, start_date desc);

create index if not exists run_log_runs_activity_session_id_idx
  on public.run_log_runs (activity_session_id);
