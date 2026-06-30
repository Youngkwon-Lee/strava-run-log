BEGIN;
ALTER TABLE public.encounters
ADD COLUMN IF NOT EXISTS care_setting text;
UPDATE public.encounters
SET care_setting = CASE class
  WHEN 'IMP' THEN 'inpatient'
  WHEN 'TELE' THEN 'telehealth'
  WHEN 'HH' THEN 'home_visit'
  ELSE 'outpatient'
END
WHERE care_setting IS NULL;
ALTER TABLE public.encounters
ALTER COLUMN care_setting SET DEFAULT 'outpatient';
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'encounters_care_setting_check'
  ) THEN
    ALTER TABLE public.encounters
    ADD CONSTRAINT encounters_care_setting_check
    CHECK (
      care_setting = ANY (
        ARRAY[
          'outpatient',
          'home_visit',
          'inpatient',
          'telehealth',
          'field_side',
          'facility'
        ]
      )
    );
  END IF;
END $$;
COMMENT ON COLUMN public.encounters.care_setting IS
'Encounter-level care setting snapshot. Distinct from org_client_profile.care_setting and location_id.';
CREATE INDEX IF NOT EXISTS idx_encounters_care_setting
ON public.encounters (care_setting);
COMMIT;
