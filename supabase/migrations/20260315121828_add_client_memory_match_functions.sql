CREATE OR REPLACE FUNCTION public.match_client_memory_chunks(
  query_embedding extensions.vector(1536),
  match_threshold double precision,
  match_count integer,
  filter_organization_id uuid,
  filter_subject_person_id uuid,
  filter_encounter_id uuid DEFAULT NULL,
  filter_body_region text DEFAULT NULL,
  filter_memory_types text[] DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  subject_person_id uuid,
  encounter_id uuid,
  author_person_id uuid,
  memory_type text,
  memory_subtype text,
  body_region text,
  title varchar,
  content text,
  summary text,
  source_table text,
  source_record_id uuid,
  chunk_index integer,
  token_count integer,
  is_current boolean,
  metadata jsonb,
  effective_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  similarity double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    cmc.id,
    cmc.organization_id,
    cmc.subject_person_id,
    cmc.encounter_id,
    cmc.author_person_id,
    cmc.memory_type,
    cmc.memory_subtype,
    cmc.body_region,
    cmc.title,
    cmc.content,
    cmc.summary,
    cmc.source_table,
    cmc.source_record_id,
    cmc.chunk_index,
    cmc.token_count,
    cmc.is_current,
    cmc.metadata,
    cmc.effective_at,
    cmc.created_at,
    cmc.updated_at,
    1 - (cmc.embedding <=> query_embedding) AS similarity
  FROM public.client_memory_chunks cmc
  WHERE cmc.organization_id = filter_organization_id
    AND cmc.subject_person_id = filter_subject_person_id
    AND cmc.embedding IS NOT NULL
    AND (filter_encounter_id IS NULL OR cmc.encounter_id = filter_encounter_id)
    AND (filter_body_region IS NULL OR cmc.body_region = filter_body_region)
    AND (
      filter_memory_types IS NULL
      OR coalesce(array_length(filter_memory_types, 1), 0) = 0
      OR cmc.memory_type = ANY(filter_memory_types)
    )
    AND 1 - (cmc.embedding <=> query_embedding) >= match_threshold
  ORDER BY cmc.embedding <=> query_embedding
  LIMIT match_count;
$$;

CREATE OR REPLACE FUNCTION public.match_client_media_summaries(
  query_embedding extensions.vector(1536),
  match_threshold double precision,
  match_count integer,
  filter_organization_id uuid,
  filter_subject_person_id uuid,
  filter_encounter_id uuid DEFAULT NULL,
  filter_body_region text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  subject_person_id uuid,
  encounter_id uuid,
  author_person_id uuid,
  media_ref_type text,
  media_ref_id uuid,
  media_kind text,
  body_region text,
  title varchar,
  summary_text text,
  structured_findings jsonb,
  metadata jsonb,
  observed_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  similarity double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    cms.id,
    cms.organization_id,
    cms.subject_person_id,
    cms.encounter_id,
    cms.author_person_id,
    cms.media_ref_type,
    cms.media_ref_id,
    cms.media_kind,
    cms.body_region,
    cms.title,
    cms.summary_text,
    cms.structured_findings,
    cms.metadata,
    cms.observed_at,
    cms.created_at,
    cms.updated_at,
    1 - (cms.embedding <=> query_embedding) AS similarity
  FROM public.client_media_summaries cms
  WHERE cms.organization_id = filter_organization_id
    AND cms.subject_person_id = filter_subject_person_id
    AND cms.embedding IS NOT NULL
    AND (filter_encounter_id IS NULL OR cms.encounter_id = filter_encounter_id)
    AND (filter_body_region IS NULL OR cms.body_region = filter_body_region)
    AND 1 - (cms.embedding <=> query_embedding) >= match_threshold
  ORDER BY cms.embedding <=> query_embedding
  LIMIT match_count;
$$;;
