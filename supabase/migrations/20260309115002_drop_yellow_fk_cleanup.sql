
-- =============================================================================
-- Yellow list FK cleanup: Drop FK constraints from active tables, then drop parent + orphan child tables
-- All FK columns confirmed 0 non-null values
-- =============================================================================

-- 1. Drop FK constraints from active tables (column stays, just nullable with no constraint)
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_recurring_template_id_fkey;
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_visit_address_id_fkey;
ALTER TABLE procedures DROP CONSTRAINT IF EXISTS procedures_based_on_service_request_id_fkey;
ALTER TABLE conversations DROP CONSTRAINT IF EXISTS conversations_lead_offer_id_fkey;

-- 2. Drop orphan child tables (0 rows, 0 code refs)
DROP TABLE IF EXISTS feature_flag_overrides CASCADE;
DROP TABLE IF EXISTS payment_refunds CASCADE;

-- 3. Drop parent tables (0 rows, 0 code refs, FKs now removed)
DROP TABLE IF EXISTS feature_flags CASCADE;
DROP TABLE IF EXISTS lead_offers CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS recurring_booking_templates CASCADE;
DROP TABLE IF EXISTS service_requests CASCADE;
DROP TABLE IF EXISTS visit_addresses CASCADE;
;
