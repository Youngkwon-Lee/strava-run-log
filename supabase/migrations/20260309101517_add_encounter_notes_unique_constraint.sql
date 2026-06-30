
-- Remove duplicate: keep the newer note (larger content_length), delete the older one
DELETE FROM encounter_notes
WHERE id = '9672a98c-d934-42ff-93c7-bc8eab62e85c';

-- Add unique constraint for atomic upsert support
CREATE UNIQUE INDEX idx_encounter_notes_encounter_format
ON encounter_notes (encounter_id, note_format);
;
