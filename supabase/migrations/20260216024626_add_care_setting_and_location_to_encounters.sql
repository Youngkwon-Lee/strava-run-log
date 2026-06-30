-- encounters에 care_setting + location 추가
ALTER TABLE encounters ADD COLUMN care_setting text;
ALTER TABLE encounters ADD COLUMN location_id uuid;

ALTER TABLE encounters ADD CONSTRAINT encounters_care_setting_check
  CHECK (care_setting IS NULL OR care_setting IN ('hospital','clinic','gym','wellness_center','home','remote','hybrid','outdoor'));

CREATE INDEX idx_encounters_care_setting ON encounters(care_setting) WHERE care_setting IS NOT NULL;
CREATE INDEX idx_encounters_location ON encounters(location_id) WHERE location_id IS NOT NULL;

COMMENT ON COLUMN encounters.care_setting IS 'Where the session took place: hospital, clinic, gym, home, remote, etc.';
COMMENT ON COLUMN encounters.location_id IS 'Optional reference to a specific location/branch within the org.';;
