
CREATE OR REPLACE FUNCTION public.hybrid_search(
  query_embedding text,
  query_text text,
  match_threshold double precision DEFAULT 0.15,
  match_count integer DEFAULT 5,
  filter_source_type text DEFAULT NULL::text,
  filter_category text DEFAULT NULL::text,
  vector_weight double precision DEFAULT 0.7,
  text_weight double precision DEFAULT 0.3
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
  created_at timestamp with time zone
)
LANGUAGE plpgsql
AS $function$
DECLARE
  embedding_vector extensions.vector(1536);
  tsquery_en       tsquery;
  tsquery_ko       tsquery;
  rrf_k            CONSTANT int := 60;
BEGIN
  -- Only parse embedding when vector search is active (avoids zero-vector NaN)
  IF vector_weight > 0 THEN
    embedding_vector := query_embedding::extensions.vector(1536);
  END IF;

  BEGIN
    tsquery_en := websearch_to_tsquery('english', query_text);
  EXCEPTION WHEN others THEN tsquery_en := NULL; END;

  BEGIN
    tsquery_ko := websearch_to_tsquery('simple', query_text);
  EXCEPTION WHEN others THEN tsquery_ko := NULL; END;

  RETURN QUERY
  WITH vector_results AS (
    SELECT
      vs.id,
      ROW_NUMBER() OVER (ORDER BY vs.embedding <=> embedding_vector) AS vrank,
      (1 - (vs.embedding <=> embedding_vector)) AS vec_sim
    FROM vector_search vs
    WHERE
      vector_weight > 0  -- skip entire CTE when text-only mode
      AND (filter_source_type IS NULL OR vs.source_type = filter_source_type)
      AND (filter_category IS NULL OR vs.category = filter_category)
      AND (1 - (vs.embedding <=> embedding_vector)) >= match_threshold
    ORDER BY vs.embedding <=> embedding_vector
    LIMIT match_count * 4
  ),
  fts_results AS (
    SELECT
      vs.id,
      ROW_NUMBER() OVER (
        ORDER BY (
          COALESCE(ts_rank_cd(vs.search_vector_ko, tsquery_ko), 0) +
          COALESCE(ts_rank_cd(vs.search_vector,    tsquery_en), 0)
        ) DESC
      ) AS frank
    FROM vector_search vs
    WHERE
      (filter_source_type IS NULL OR vs.source_type = filter_source_type)
      AND (filter_category IS NULL OR vs.category = filter_category)
      AND (
        (tsquery_ko IS NOT NULL AND vs.search_vector_ko @@ tsquery_ko)
        OR
        (tsquery_en IS NOT NULL AND vs.search_vector    @@ tsquery_en)
      )
    LIMIT match_count * 4
  ),
  rrf_scores AS (
    SELECT
      COALESCE(vr.id, fr.id)   AS doc_id,
      COALESCE(vr.vec_sim, 0)  AS vec_sim,
      (
        vector_weight * COALESCE(1.0 / (rrf_k + vr.vrank), 0) +
        text_weight   * COALESCE(1.0 / (rrf_k + fr.frank), 0)
      )                        AS rrf_score
    FROM vector_results vr
    FULL OUTER JOIN fts_results fr ON vr.id = fr.id
  )
  SELECT
    vs.id, vs.source_type::text, vs.source_id::text,
    vs.title, vs.content, vs.category::text, vs.metadata,
    rrf.vec_sim AS similarity,
    vs.created_at
  FROM rrf_scores rrf
  JOIN vector_search vs ON vs.id = rrf.doc_id
  ORDER BY rrf.rrf_score DESC
  LIMIT match_count;
END;
$function$;
;
