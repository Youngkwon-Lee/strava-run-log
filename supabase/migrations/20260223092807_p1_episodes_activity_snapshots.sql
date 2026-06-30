-- ============================================================
-- P1 Migration: episodes + activity_sessions + chat_context_snapshots
-- Date: 2026-02-23
-- ============================================================

-- 1. episodes (FHIR EpisodeOfCare)
CREATE TABLE IF NOT EXISTS public.episodes (
  id                    UUID        NOT NULL DEFAULT gen_random_uuid(),
  fhir_id               TEXT        GENERATED ALWAYS AS ('EpisodeOfCare/' || id::text) STORED,
  subject_person_id     UUID        NOT NULL,
  organization_id       UUID        NOT NULL,
  condition_id          UUID        NULL,
  status                TEXT        NOT NULL DEFAULT 'active'
                          CHECK (status IN (
                            'planned','waitlist','active','onhold',
                            'finished','cancelled','entered-in-error'
                          )),
  episode_type          TEXT        NOT NULL DEFAULT 'rehabilitation'
                          CHECK (episode_type IN (
                            'rehabilitation','prevention','chronic_management',
                            'sports_performance','wellness','post_surgical','other'
                          )),
  period_start          DATE        NOT NULL DEFAULT CURRENT_DATE,
  period_end            DATE        NULL,
  title                 TEXT        NOT NULL,
  description           TEXT        NULL,
  primary_provider_id   UUID        NULL,
  care_team_ids         UUID[]      DEFAULT '{}',
  goal_summary          TEXT        NULL,
  finish_reason         TEXT        NULL,
  created_by            UUID        NULL,
  updated_by            UUID        NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at            TIMESTAMPTZ NULL,
  CONSTRAINT episodes_pkey PRIMARY KEY (id)
);

ALTER TABLE public.encounters
  ADD COLUMN IF NOT EXISTS episode_id UUID NULL
    REFERENCES public.episodes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_episodes_subject_person
  ON public.episodes (subject_person_id);
CREATE INDEX IF NOT EXISTS idx_episodes_org
  ON public.episodes (organization_id);
CREATE INDEX IF NOT EXISTS idx_episodes_condition
  ON public.episodes (condition_id)
  WHERE condition_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_episodes_status
  ON public.episodes (status)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_episodes_period
  ON public.episodes (period_start, period_end)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_encounters_episode
  ON public.encounters (episode_id)
  WHERE episode_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS episodes_set_updated_at ON public.episodes;
CREATE TRIGGER episodes_set_updated_at
  BEFORE UPDATE ON public.episodes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.episodes ENABLE ROW LEVEL SECURITY;

CREATE POLICY episodes_provider_select ON public.episodes
  FOR SELECT USING (
    deleted_at IS NULL AND
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = episodes.organization_id
        AND om.role = ANY(ARRAY['owner','admin','provider','staff'])
        AND om.status = 'active'
    )
  );

CREATE POLICY episodes_client_select ON public.episodes
  FOR SELECT USING (
    deleted_at IS NULL AND
    subject_person_id = get_my_person_id()
  );

CREATE POLICY episodes_insert ON public.episodes
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = episodes.organization_id
        AND om.role = ANY(ARRAY['owner','admin','provider','staff'])
        AND om.status = 'active'
    )
  );

CREATE POLICY episodes_update ON public.episodes
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = episodes.organization_id
        AND om.role = ANY(ARRAY['owner','admin','provider'])
        AND om.status = 'active'
    )
  );

-- 2. activity_sessions (FHIR Procedure 확장)
CREATE TABLE IF NOT EXISTS public.activity_sessions (
  id                    UUID        NOT NULL DEFAULT gen_random_uuid(),
  subject_person_id     UUID        NOT NULL,
  organization_id       UUID        NULL,
  episode_id            UUID        NULL,
  encounter_id          UUID        NULL,
  care_plan_id          UUID        NULL,
  activity_type         TEXT        NOT NULL DEFAULT 'home_exercise'
                          CHECK (activity_type IN (
                            'home_exercise','clinic_exercise','gym_training',
                            'competition','assessment','daily_walk','telehealth','other'
                          )),
  source                TEXT        NOT NULL DEFAULT 'manual'
                          CHECK (source IN (
                            'manual','apple_health','samsung_health',
                            'garmin','imu','camera','app_guided'
                          )),
  status                TEXT        NOT NULL DEFAULT 'completed'
                          CHECK (status IN (
                            'planned','in_progress','completed','cancelled','skipped'
                          )),
  performed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  duration_seconds      INTEGER     NULL,
  metrics               JSONB       NOT NULL DEFAULT '{}',
  exercise_log          JSONB       NULL,
  notes                 TEXT        NULL,
  difficulty_note       TEXT        NULL,
  has_timeseries        BOOLEAN     NOT NULL DEFAULT false,
  timeseries_ref        JSONB       NULL,
  created_by            UUID        NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT activity_sessions_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_activity_sessions_subject
  ON public.activity_sessions (subject_person_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_sessions_episode
  ON public.activity_sessions (episode_id)
  WHERE episode_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activity_sessions_encounter
  ON public.activity_sessions (encounter_id)
  WHERE encounter_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activity_sessions_type_status
  ON public.activity_sessions (activity_type, status);
CREATE INDEX IF NOT EXISTS idx_activity_sessions_performed
  ON public.activity_sessions (performed_at DESC);

DROP TRIGGER IF EXISTS activity_sessions_set_updated_at ON public.activity_sessions;
CREATE TRIGGER activity_sessions_set_updated_at
  BEFORE UPDATE ON public.activity_sessions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.activity_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY activity_sessions_provider_select ON public.activity_sessions
  FOR SELECT USING (
    organization_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = activity_sessions.organization_id
        AND om.role = ANY(ARRAY['owner','admin','provider','staff'])
        AND om.status = 'active'
    )
  );

CREATE POLICY activity_sessions_client_select ON public.activity_sessions
  FOR SELECT USING (
    subject_person_id = get_my_person_id()
  );

CREATE POLICY activity_sessions_insert ON public.activity_sessions
  FOR INSERT WITH CHECK (
    subject_person_id = get_my_person_id()
    OR (
      organization_id IS NOT NULL AND
      EXISTS (
        SELECT 1 FROM organization_members om
        WHERE om.person_id = get_my_person_id()
          AND om.organization_id = activity_sessions.organization_id
          AND om.role = ANY(ARRAY['owner','admin','provider','staff'])
          AND om.status = 'active'
      )
    )
  );

CREATE POLICY activity_sessions_update ON public.activity_sessions
  FOR UPDATE USING (
    subject_person_id = get_my_person_id()
    OR (
      organization_id IS NOT NULL AND
      EXISTS (
        SELECT 1 FROM organization_members om
        WHERE om.person_id = get_my_person_id()
          AND om.organization_id = activity_sessions.organization_id
          AND om.role = ANY(ARRAY['owner','admin','provider'])
          AND om.status = 'active'
      )
    )
  );

-- 3. chat_context_snapshots (LLM Read Model)
CREATE TABLE IF NOT EXISTS public.chat_context_snapshots (
  id                    UUID        NOT NULL DEFAULT gen_random_uuid(),
  scope_type            TEXT        NOT NULL
                          CHECK (scope_type IN ('episode','encounter','weekly')),
  scope_id              UUID        NOT NULL,
  week_start            DATE        NULL,
  subject_person_id     UUID        NOT NULL,
  organization_id       UUID        NOT NULL,
  summary_short         TEXT        NULL,
  summary_json          JSONB       NOT NULL DEFAULT '{}',
  computed_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at            TIMESTAMPTZ NULL,
  is_stale              BOOLEAN     NOT NULL DEFAULT false,
  source_record_ids     UUID[]      DEFAULT '{}',
  source_tables         TEXT[]      DEFAULT '{}',
  last_used_at          TIMESTAMPTZ NULL,
  use_count             INTEGER     NOT NULL DEFAULT 0,
  CONSTRAINT chat_context_snapshots_pkey PRIMARY KEY (id),
  CONSTRAINT chat_context_snapshots_scope_unique
    UNIQUE (scope_type, scope_id)
);

CREATE INDEX IF NOT EXISTS idx_snapshots_subject_scope
  ON public.chat_context_snapshots (subject_person_id, scope_type);
CREATE INDEX IF NOT EXISTS idx_snapshots_scope
  ON public.chat_context_snapshots (scope_id);
CREATE INDEX IF NOT EXISTS idx_snapshots_stale
  ON public.chat_context_snapshots (is_stale)
  WHERE is_stale = true;
CREATE INDEX IF NOT EXISTS idx_snapshots_expires
  ON public.chat_context_snapshots (expires_at)
  WHERE expires_at IS NOT NULL;

ALTER TABLE public.chat_context_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY snapshots_provider_select ON public.chat_context_snapshots
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = chat_context_snapshots.organization_id
        AND om.role = ANY(ARRAY['owner','admin','provider','staff'])
        AND om.status = 'active'
    )
  );

CREATE POLICY snapshots_client_select ON public.chat_context_snapshots
  FOR SELECT USING (
    subject_person_id = get_my_person_id()
  );

CREATE POLICY snapshots_service_role_all ON public.chat_context_snapshots
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 4. job_queue 트리거 함수
CREATE OR REPLACE FUNCTION public.queue_snapshot_refresh(
  p_scope_type TEXT,
  p_scope_id   UUID,
  p_person_id  UUID,
  p_org_id     UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.chat_context_snapshots
  SET is_stale = true
  WHERE scope_type = p_scope_type
    AND scope_id = p_scope_id;

  INSERT INTO public.job_queue (job_type, payload, priority, organization_id)
  SELECT
    'snapshot_refresh',
    jsonb_build_object(
      'scope_type', p_scope_type,
      'scope_id',   p_scope_id,
      'person_id',  p_person_id,
      'org_id',     p_org_id
    ),
    5,
    p_org_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.job_queue
    WHERE job_type = 'snapshot_refresh'
      AND status = 'pending'
      AND payload->>'scope_id' = p_scope_id::text
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_queue_encounter_snapshot()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  PERFORM public.queue_snapshot_refresh(
    'encounter',
    NEW.id,
    NEW.subject_person_id,
    NEW.organization_id
  );
  IF NEW.episode_id IS NOT NULL THEN
    PERFORM public.queue_snapshot_refresh(
      'episode',
      NEW.episode_id,
      NEW.subject_person_id,
      NEW.organization_id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_encounters_queue_snapshot ON public.encounters;
CREATE TRIGGER trg_encounters_queue_snapshot
  AFTER INSERT OR UPDATE ON public.encounters
  FOR EACH ROW EXECUTE FUNCTION public.trg_queue_encounter_snapshot();

CREATE OR REPLACE FUNCTION public.trg_queue_activity_snapshot()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.episode_id IS NOT NULL THEN
    PERFORM public.queue_snapshot_refresh(
      'episode',
      NEW.episode_id,
      NEW.subject_person_id,
      COALESCE(NEW.organization_id, '00000000-0000-0000-0000-000000000000'::uuid)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_activity_sessions_queue_snapshot ON public.activity_sessions;
CREATE TRIGGER trg_activity_sessions_queue_snapshot
  AFTER INSERT OR UPDATE ON public.activity_sessions
  FOR EACH ROW EXECUTE FUNCTION public.trg_queue_activity_snapshot();

-- 5. v_episode_summary 뷰
CREATE OR REPLACE VIEW public.v_episode_summary AS
SELECT
  e.id,
  e.subject_person_id,
  e.organization_id,
  e.status,
  e.episode_type,
  e.title,
  e.period_start,
  e.period_end,
  e.primary_provider_id,
  COUNT(DISTINCT enc.id)  AS encounter_count,
  COUNT(DISTINCT act.id)  AS activity_count,
  MAX(act.performed_at)   AS last_activity_at,
  snap.computed_at        AS snapshot_computed_at,
  snap.is_stale           AS snapshot_is_stale
FROM public.episodes e
LEFT JOIN public.encounters enc
  ON enc.episode_id = e.id AND enc.deleted_at IS NULL
LEFT JOIN public.activity_sessions act
  ON act.episode_id = e.id
LEFT JOIN public.chat_context_snapshots snap
  ON snap.scope_type = 'episode' AND snap.scope_id = e.id
WHERE e.deleted_at IS NULL
GROUP BY e.id, snap.computed_at, snap.is_stale;;
