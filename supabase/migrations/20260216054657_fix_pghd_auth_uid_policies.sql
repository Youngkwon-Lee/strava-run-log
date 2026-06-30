DROP POLICY IF EXISTS "pghd_connections_delete" ON pghd_connections;
CREATE POLICY "pghd_connections_delete" ON pghd_connections FOR DELETE USING (person_id = get_my_person_id());

DROP POLICY IF EXISTS "pghd_connections_select" ON pghd_connections;
CREATE POLICY "pghd_connections_select" ON pghd_connections FOR SELECT USING (person_id = get_my_person_id());

DROP POLICY IF EXISTS "pghd_connections_update" ON pghd_connections;
CREATE POLICY "pghd_connections_update" ON pghd_connections FOR UPDATE USING (person_id = get_my_person_id());

DROP POLICY IF EXISTS "pghd_connections_user_access" ON pghd_connections;
CREATE POLICY "pghd_connections_user_access" ON pghd_connections FOR ALL USING (person_id = get_my_person_id());

DROP POLICY IF EXISTS "pghd_oauth_sessions_user_access" ON pghd_oauth_sessions;
CREATE POLICY "pghd_oauth_sessions_user_access" ON pghd_oauth_sessions FOR ALL USING (person_id = get_my_person_id());

DROP POLICY IF EXISTS "own_pghd_daily_summaries" ON pghd_daily_summaries;
CREATE POLICY "own_pghd_daily_summaries" ON pghd_daily_summaries FOR SELECT USING (person_id = get_my_person_id());;
