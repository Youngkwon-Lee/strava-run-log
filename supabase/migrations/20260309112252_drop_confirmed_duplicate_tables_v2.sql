
-- Drop 8 confirmed duplicate/replaced tables (all 0 rows, no incoming FKs)
DROP TABLE IF EXISTS classification_systems CASCADE;
DROP TABLE IF EXISTS code_systems CASCADE;
DROP TABLE IF EXISTS soap_note_observations CASCADE;
DROP TABLE IF EXISTS organization_persons CASCADE;
DROP TABLE IF EXISTS red_flag_alerts CASCADE;
DROP TABLE IF EXISTS content_body_sites CASCADE;
DROP TABLE IF EXISTS content_categories CASCADE;
DROP TABLE IF EXISTS content_codings CASCADE;

-- professional_profiles is a materialized view, not a table
DROP MATERIALIZED VIEW IF EXISTS professional_profiles CASCADE;
;
