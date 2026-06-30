revoke all on table public.icf_reference from anon;
revoke all on table public.icf_reference from authenticated;

grant select on table public.icf_reference to authenticated;

alter table public.icf_reference enable row level security;

drop policy if exists icf_reference_read_authenticated on public.icf_reference;

create policy icf_reference_read_authenticated
  on public.icf_reference
  for select
  to authenticated
  using (true);;
