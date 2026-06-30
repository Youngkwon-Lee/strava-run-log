-- Wave 3 legacy function cleanup
-- Drop orphan trigger helper left behind after red_flag_alerts table removal.
-- Verified before apply:
--   - public.trigger_red_flag_alerts_updated_at() exists in live DB
--   - no non-internal trigger attachments remain in public
--   - no pg_depend entries point to the function

drop function if exists public.trigger_red_flag_alerts_updated_at();
