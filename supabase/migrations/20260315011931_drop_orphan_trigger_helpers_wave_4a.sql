-- Drop orphan trigger-helper residue verified in Wave 4A review.
-- Preconditions verified on 2026-03-15:
--   - all 7 functions existed in live `public`
--   - all 7 had zero non-internal trigger attachments
--   - repo exact-name search returned no runtime call sites
--   - live function-body search returned no internal references
--   - `cron.job` search returned zero matches

drop function if exists public.trg_ensure_single_default_address();
drop function if exists public.trg_visit_addresses_updated_at();
drop function if exists public.update_appointment_reminders_updated_at();
drop function if exists public.update_bookings_updated_at();
drop function if exists public.update_feature_flags_updated_at();
drop function if exists public.update_goals_updated_at();
drop function if exists public.update_payments_updated_at();;
