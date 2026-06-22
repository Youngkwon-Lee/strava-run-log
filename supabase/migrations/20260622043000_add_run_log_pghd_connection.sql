alter table public.run_log_runs
  add column if not exists pghd_connection_id uuid;

comment on column public.run_log_runs.pghd_connection_id is
  'Resolved provider connection id from pghd_connections when a run can be mapped to a person/provider account.';

create index if not exists run_log_runs_pghd_connection_id_idx
  on public.run_log_runs (pghd_connection_id);
