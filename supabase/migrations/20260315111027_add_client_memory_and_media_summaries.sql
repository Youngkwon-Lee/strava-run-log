CREATE TABLE IF NOT EXISTS client_memory_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  subject_person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  encounter_id UUID REFERENCES encounters(id) ON DELETE SET NULL,
  author_person_id UUID REFERENCES persons(id) ON DELETE SET NULL,
  memory_type TEXT NOT NULL CHECK (
    memory_type IN (
      'intake',
      'soap',
      'assessment',
      'special_test',
      'exercise_log',
      'provider_note',
      'client_report',
      'outcome_trend',
      'care_plan'
    )
  ),
  memory_subtype TEXT,
  body_region TEXT CHECK (
    body_region IS NULL OR body_region IN (
      'lumbar',
      'cervical',
      'shoulder',
      'knee',
      'ankle',
      'hip'
    )
  ),
  title VARCHAR(255),
  content TEXT NOT NULL,
  summary TEXT,
  source_table TEXT,
  source_record_id UUID,
  chunk_index INTEGER NOT NULL DEFAULT 0 CHECK (chunk_index >= 0),
  token_count INTEGER CHECK (token_count IS NULL OR token_count >= 0),
  is_current BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  embedding extensions.vector(1536),
  effective_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (organization_id, source_table, source_record_id, chunk_index)
);
CREATE INDEX IF NOT EXISTS idx_client_memory_subject_effective
  ON client_memory_chunks(subject_person_id, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_memory_subject_encounter
  ON client_memory_chunks(subject_person_id, encounter_id, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_memory_org_type_effective
  ON client_memory_chunks(organization_id, memory_type, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_memory_org_region_effective
  ON client_memory_chunks(organization_id, body_region, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_memory_metadata_gin
  ON client_memory_chunks USING gin (metadata jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_client_memory_embedding_ivfflat
  ON client_memory_chunks
  USING ivfflat (embedding extensions.vector_cosine_ops)
  WITH (lists = 100);

CREATE TABLE IF NOT EXISTS client_media_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  subject_person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  encounter_id UUID REFERENCES encounters(id) ON DELETE SET NULL,
  author_person_id UUID REFERENCES persons(id) ON DELETE SET NULL,
  media_ref_type TEXT NOT NULL CHECK (
    media_ref_type IN (
      'encounter_file',
      'voice_memo',
      'image_upload',
      'video_upload'
    )
  ),
  media_ref_id UUID,
  media_kind TEXT NOT NULL CHECK (
    media_kind IN (
      'image',
      'video',
      'audio',
      'document'
    )
  ),
  body_region TEXT CHECK (
    body_region IS NULL OR body_region IN (
      'lumbar',
      'cervical',
      'shoulder',
      'knee',
      'ankle',
      'hip'
    )
  ),
  title VARCHAR(255),
  summary_text TEXT NOT NULL,
  structured_findings JSONB NOT NULL DEFAULT '{}'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  embedding extensions.vector(1536),
  observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (organization_id, media_ref_type, media_ref_id)
);
CREATE INDEX IF NOT EXISTS idx_client_media_subject_observed
  ON client_media_summaries(subject_person_id, observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_media_subject_encounter
  ON client_media_summaries(subject_person_id, encounter_id, observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_media_org_kind_observed
  ON client_media_summaries(organization_id, media_kind, observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_media_findings_gin
  ON client_media_summaries USING gin (structured_findings jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_client_media_embedding_ivfflat
  ON client_media_summaries
  USING ivfflat (embedding extensions.vector_cosine_ops)
  WITH (lists = 100);

ALTER TABLE client_memory_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_media_summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "client_memory_org_read" ON client_memory_chunks
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_memory_chunks.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider', 'staff')
    )
  );
CREATE POLICY "client_media_org_read" ON client_media_summaries
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_media_summaries.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider', 'staff')
    )
  );
CREATE POLICY "client_memory_org_write" ON client_memory_chunks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_memory_chunks.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider')
    )
  );
CREATE POLICY "client_memory_org_update" ON client_memory_chunks
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_memory_chunks.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_memory_chunks.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider')
    )
  );
CREATE POLICY "client_media_org_write" ON client_media_summaries
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_media_summaries.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider')
    )
  );
CREATE POLICY "client_media_org_update" ON client_media_summaries
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_media_summaries.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM organization_members om
      WHERE om.organization_id = client_media_summaries.organization_id
        AND om.person_id = get_my_person_id()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin', 'provider')
    )
  );;
