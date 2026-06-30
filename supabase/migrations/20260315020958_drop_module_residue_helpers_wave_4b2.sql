-- Drop module-level residue helpers verified in Wave 4B2 review.
-- Preconditions verified on 2026-03-15:
--   - target tables `appointments`, `fhir_resource`, `ml_profile`, `waitlist` are absent from live `public`
--   - all 8 functions have zero non-internal trigger attachments
--   - exact-name repo scan found no runtime call sites outside generated types
--   - pg_depend / pg_proc / pg_views / pg_policies / cron.job scans found no references
--   - pg_stat_user_functions reports zero calls for all 8 functions

drop function if exists public.update_appointments_updated_at();
drop function if exists public.update_appointment_on_session_completion();
drop function if exists public.update_fhir_resource_updated_at();
drop function if exists public.validate_fhir_resource(jsonb);
drop function if exists public.update_ml_profile_updated_at();
drop function if exists public.validate_ml_profile_features(jsonb);
drop function if exists public.update_waitlist_updated_at();
drop function if exists public.set_waitlist_expires_at();;
