alter table if exists public.pilot_patients enable row level security;
alter table if exists public.pilot_encounters enable row level security;
alter table if exists public.patient_memories enable row level security;

drop policy if exists "pilot patients full access" on public.pilot_patients;
create policy "pilot patients full access"
on public.pilot_patients for all using (true) with check (true);

drop policy if exists "pilot encounters full access" on public.pilot_encounters;
create policy "pilot encounters full access"
on public.pilot_encounters for all using (true) with check (true);

drop policy if exists "patient memories full access" on public.patient_memories;
create policy "patient memories full access"
on public.patient_memories for all using (true) with check (true);;
