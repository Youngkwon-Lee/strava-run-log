-- Security hardening: remove Data API exposure from client dashboard materialized view
-- Date: 2026-03-14

revoke all on public.mv_client_dashboard_summary from anon, authenticated;
