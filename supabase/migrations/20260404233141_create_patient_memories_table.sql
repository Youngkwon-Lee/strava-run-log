create table if not exists public.patient_memories (
  memory_id uuid primary key,
  patient_id uuid not null,
  updated_at timestamptz not null default now(),
  summary text not null,
  recent_priorities text[] not null default '{}',
  follow_up_points text[] not null default '{}',
  adherence_risks text[] not null default '{}'
);

create unique index if not exists idx_patient_memories_patient_id on public.patient_memories(patient_id);;
