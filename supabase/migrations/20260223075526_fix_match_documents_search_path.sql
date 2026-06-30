CREATE OR REPLACE FUNCTION public.match_documents(
  query_embedding text,
  match_threshold double precision DEFAULT 0.60,
  match_count integer DEFAULT 10,
  filter_source_type text DEFAULT NULL,
  filter_category text DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  source_type text,
  source_id text,
  title text,
  content text,
  category text,
  metadata jsonb,
  similarity double precision,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  embedding_vector extensions.vector(1536);
BEGIN
  embedding_vector := query_embedding::extensions.vector(1536);

  RETURN QUERY
  SELECT
    vs.id,
    vs.source_type::text,
    vs.source_id::text,
    vs.title,
    vs.content,
    vs.category::text,
    vs.metadata,
    1 - (vs.embedding <=> embedding_vector) AS similarity,
    vs.created_at
  FROM vector_search vs
  WHERE
    (filter_source_type IS NULL OR vs.source_type = filter_source_type)
    AND (filter_category IS NULL OR vs.category = filter_category)
    AND (1 - (vs.embedding <=> embedding_vector)) > match_threshold
  ORDER BY vs.embedding <=> embedding_vector
  LIMIT match_count;
END;
$$;;
