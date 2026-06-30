-- Allow encounter/activity snapshot triggers to call the locked-down queue helper.
--
-- 20260515124153 intentionally restricted public SECURITY DEFINER RPC execution
-- to service_role, which also removed authenticated EXECUTE from
-- queue_snapshot_refresh(). These trigger functions run during authenticated
-- writes, so make the trigger boundary privileged instead of reopening the
-- queue helper as a callable RPC.

alter function public.trg_queue_encounter_snapshot()
  security definer
  set search_path = public, extensions, pg_temp;
alter function public.trg_queue_activity_snapshot()
  security definer
  set search_path = public, extensions, pg_temp;
revoke execute on function public.trg_queue_encounter_snapshot() from public, anon, authenticated;
revoke execute on function public.trg_queue_activity_snapshot() from public, anon, authenticated;
grant execute on function public.trg_queue_encounter_snapshot() to service_role;
grant execute on function public.trg_queue_activity_snapshot() to service_role;
