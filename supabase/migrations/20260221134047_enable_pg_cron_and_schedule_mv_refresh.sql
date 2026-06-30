-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule mv_client_dashboard_summary refresh daily at 18:00 UTC (03:00 KST)
SELECT cron.schedule(
  'refresh-client-dashboard',
  '0 18 * * *',
  'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_client_dashboard_summary'
);;
