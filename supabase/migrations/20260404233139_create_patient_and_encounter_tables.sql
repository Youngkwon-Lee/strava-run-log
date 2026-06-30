create table if not exists public.pilot_patients (
  patient_id uuid primary key,
  display_name text not null,
  age integer not null,
  sex text not null,
  setting text not null,
  primary_goal text not null,
  risk_flags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pilot_encounters (
  encounter_id uuid primary key,
  patient_id uuid not null references public.pilot_patients(patient_id) on delete cascade,
  encounter_label text not null,
  phase text not null,
  status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_pilot_encounters_patient_id on public.pilot_encounters(patient_id, created_at desc);;
