
-- Gap 1: observations.activity_session_id FK 추가
-- 세션 metrics JSONB → observations 테이블 연결
-- Note: encounter_id NOT NULL 유지 (Phase 1 — encounter 있는 세션만 추출)
--       Phase 2에서 encounter_id nullable + RLS 정책 업데이트 예정

ALTER TABLE observations
  ADD COLUMN IF NOT EXISTS activity_session_id UUID
    REFERENCES activity_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS observations_activity_session_id_idx
  ON observations(activity_session_id)
  WHERE activity_session_id IS NOT NULL;

-- Gap 2: pghd_observations에 episode/session 연결 추가
-- 웨어러블 데이터를 특정 재활 에피소드에 귀속 가능하게 함

ALTER TABLE pghd_observations
  ADD COLUMN IF NOT EXISTS episode_id UUID
    REFERENCES episodes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS activity_session_id UUID
    REFERENCES activity_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS pghd_observations_episode_id_idx
  ON pghd_observations(episode_id)
  WHERE episode_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS pghd_observations_session_id_idx
  ON pghd_observations(activity_session_id)
  WHERE activity_session_id IS NOT NULL;

COMMENT ON COLUMN observations.activity_session_id IS
  'Session-linked observation (home exercise, gym session metrics extraction). '
  'Phase 1: only populated for sessions WITH encounter_id. '
  'Phase 2: encounter_id will be made nullable to support encounter-free sessions.';

COMMENT ON COLUMN pghd_observations.episode_id IS
  'Links wearable/PGHD data to a specific rehabilitation or training episode. '
  'Closes the PGHD→Episode graph gap for AI timeline queries.';

COMMENT ON COLUMN pghd_observations.activity_session_id IS
  'Links PGHD data to a specific activity session for granular session-level analytics.';
;
