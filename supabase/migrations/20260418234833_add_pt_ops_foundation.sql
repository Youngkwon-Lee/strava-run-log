-- PT Ops foundation schema (MVP)
-- Scope: inquiry -> appointment -> reminder -> SOAP

create extension if not exists pgcrypto;
create table if not exists public.centers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.therapists (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  name text not null,
  role text not null default 'therapist',
  created_at timestamptz not null default now()
);
create table if not exists public.patients (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  name text not null,
  phone text,
  first_visit_date date,
  created_at timestamptz not null default now()
);
create table if not exists public.inquiries (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  patient_id uuid references public.patients(id) on delete set null,
  source text not null default 'naver_place',
  message text,
  tag text,
  status text not null default 'new', -- new/contacted/converted/closed
  created_at timestamptz not null default now()
);
create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  therapist_id uuid references public.therapists(id) on delete set null,
  starts_at timestamptz not null,
  status text not null default 'booked', -- booked/completed/cancelled/no_show
  created_at timestamptz not null default now()
);
create table if not exists public.attendance_logs (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  result text not null, -- visit/no_show/cancelled
  note text,
  created_at timestamptz not null default now()
);
create table if not exists public.session_notes (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  therapist_id uuid references public.therapists(id) on delete set null,
  appointment_id uuid references public.appointments(id) on delete set null,
  s_text text,
  o_text text,
  a_text text,
  p_text text,
  ai_draft boolean not null default true,
  final_signed boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.message_logs (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  patient_id uuid references public.patients(id) on delete set null,
  appointment_id uuid references public.appointments(id) on delete set null,
  channel text not null default 'sms',
  template_key text,
  status text not null default 'queued', -- queued/sent/failed
  sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_inquiries_center_created on public.inquiries(center_id, created_at desc);
create index if not exists idx_appointments_center_starts on public.appointments(center_id, starts_at desc);
create index if not exists idx_attendance_appointment on public.attendance_logs(appointment_id);
create index if not exists idx_session_notes_center_created on public.session_notes(center_id, created_at desc);
create index if not exists idx_message_logs_center_created on public.message_logs(center_id, created_at desc);
