-- Purpose:
--   Lock down likely-unused legacy tables that currently expose broad public ALL access.
--
-- Scope:
--   public.agent_runs
--   public.background_jobs
--   public.patient_memories
--   public.pilot_encounters
--   public.pilot_patients
--
-- Rationale:
--   These tables appear in live schema but have no current app/src/scripts/e2e usage
--   beyond generated DB docs. Until proven active, remove public ALL policies and
--   restrict access to service_role only.

-- agent_runs
DROP POLICY IF EXISTS "agent runs full access" ON public.agent_runs;
CREATE POLICY "agent_runs_service_only"
  ON public.agent_runs
  AS PERMISSIVE FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
-- background_jobs
DROP POLICY IF EXISTS "background jobs full access" ON public.background_jobs;
CREATE POLICY "background_jobs_service_only"
  ON public.background_jobs
  AS PERMISSIVE FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
-- patient_memories
DROP POLICY IF EXISTS "patient memories full access" ON public.patient_memories;
CREATE POLICY "patient_memories_service_only"
  ON public.patient_memories
  AS PERMISSIVE FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
-- pilot_encounters
DROP POLICY IF EXISTS "pilot encounters full access" ON public.pilot_encounters;
CREATE POLICY "pilot_encounters_service_only"
  ON public.pilot_encounters
  AS PERMISSIVE FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
-- pilot_patients
DROP POLICY IF EXISTS "pilot patients full access" ON public.pilot_patients;
CREATE POLICY "pilot_patients_service_only"
  ON public.pilot_patients
  AS PERMISSIVE FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
