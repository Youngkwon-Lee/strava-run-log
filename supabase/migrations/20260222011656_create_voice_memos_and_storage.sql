
-- ============================================================
-- voice_memos table + RLS + Storage bucket
-- Pattern: matches encounter_notes RLS (org membership check)
-- ============================================================

-- 1. Create table
CREATE TABLE IF NOT EXISTS voice_memos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  encounter_id  uuid NOT NULL REFERENCES encounters(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  subject_person_id uuid NOT NULL REFERENCES persons(id),
  provider_person_id uuid NOT NULL REFERENCES persons(id),
  file_path     text NOT NULL,
  file_size_bytes integer NOT NULL DEFAULT 0,
  duration_seconds numeric NOT NULL DEFAULT 0,
  processing_status text NOT NULL DEFAULT 'pending'
    CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
  recorded_at   timestamptz NOT NULL DEFAULT now(),
  -- Transcription columns
  transcript_text     text,
  transcript_segments jsonb,
  processing_error    text,
  processed_at        timestamptz,
  -- Audit
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE voice_memos IS 'Voice recordings attached to encounters, with STT transcription';
COMMENT ON COLUMN voice_memos.transcript_text IS 'Full transcription text from STT';
COMMENT ON COLUMN voice_memos.transcript_segments IS 'Word/segment-level timestamps [{start, end, text, confidence}]';
COMMENT ON COLUMN voice_memos.processing_error IS 'Error message if transcription failed';
COMMENT ON COLUMN voice_memos.processed_at IS 'When transcription completed or failed';

-- 2. Indexes
CREATE INDEX idx_voice_memos_encounter ON voice_memos(encounter_id);
CREATE INDEX idx_voice_memos_org ON voice_memos(organization_id);
CREATE INDEX idx_voice_memos_subject ON voice_memos(subject_person_id);
CREATE INDEX idx_voice_memos_status ON voice_memos(processing_status);

-- 3. updated_at trigger (reuse existing function)
CREATE TRIGGER set_voice_memos_updated_at
  BEFORE UPDATE ON voice_memos
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 4. RLS (matches encounter_notes pattern)
ALTER TABLE voice_memos ENABLE ROW LEVEL SECURITY;

-- SELECT: org members with clinical roles
CREATE POLICY voice_memos_org_read ON voice_memos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = voice_memos.organization_id
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider', 'staff')
    )
  );

-- INSERT: org members with clinical roles
CREATE POLICY voice_memos_org_insert ON voice_memos
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = voice_memos.organization_id
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider', 'staff')
    )
  );

-- UPDATE: only the recording provider (author)
CREATE POLICY voice_memos_author_update ON voice_memos
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.person_id = voice_memos.provider_person_id
        AND om.organization_id = voice_memos.organization_id
        AND om.status = 'active'
    )
  );

-- DELETE: only the recording provider, and only pending status
CREATE POLICY voice_memos_author_delete ON voice_memos
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.person_id = voice_memos.provider_person_id
        AND om.organization_id = voice_memos.organization_id
        AND om.status = 'active'
    )
    AND processing_status = 'pending'
  );

-- 5. Storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'clinical-files',
  'clinical-files',
  false,
  52428800,  -- 50MB
  ARRAY['audio/webm', 'audio/mp3', 'audio/wav', 'audio/mpeg', 'audio/ogg', 'audio/m4a',
        'image/jpeg', 'image/png', 'image/gif', 'image/webp',
        'application/pdf', 'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/csv']
)
ON CONFLICT (id) DO NOTHING;

-- 6. Storage RLS policies
CREATE POLICY storage_clinical_upload ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'clinical-files'
    AND (storage.foldername(name))[1] IS NOT NULL
  );

CREATE POLICY storage_clinical_read ON storage.objects
  FOR SELECT USING (
    bucket_id = 'clinical-files'
  );

CREATE POLICY storage_clinical_delete ON storage.objects
  FOR DELETE USING (
    bucket_id = 'clinical-files'
  );
;
