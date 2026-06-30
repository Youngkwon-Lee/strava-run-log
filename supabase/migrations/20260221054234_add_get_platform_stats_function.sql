
CREATE OR REPLACE FUNCTION get_platform_stats()
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT json_build_object(
    'table_count', (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'),
    'policy_count', (SELECT count(*) FROM pg_policies WHERE schemaname = 'public'),
    'db_size_mb', (SELECT round(pg_database_size(current_database()) / 1048576.0, 1))
  );
$$;
;
