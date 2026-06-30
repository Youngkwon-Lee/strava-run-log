-- Remove temporary PT Ops foundation tables
-- Reason: align with existing person-centric physio_app schema

drop table if exists public.attendance_logs;
drop table if exists public.message_logs;
drop table if exists public.session_notes;
drop table if exists public.appointments;
drop table if exists public.inquiries;
drop table if exists public.patients;
drop table if exists public.therapists;
drop table if exists public.centers;
