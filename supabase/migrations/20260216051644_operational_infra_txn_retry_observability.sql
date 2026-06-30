CREATE TABLE IF NOT EXISTS workflow_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id uuid NOT NULL,
  workflow_type text NOT NULL,
  step_name text NOT NULL,
  step_order int NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  input_data jsonb,
  output_data jsonb,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  compensated_at timestamptz,
  organization_id uuid REFERENCES organizations(id),
  actor_person_id uuid REFERENCES persons(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT workflow_steps_status_check CHECK (status IN ('pending', 'running', 'completed', 'failed', 'compensating', 'compensated', 'skipped')),
  CONSTRAINT workflow_steps_unique_step UNIQUE (workflow_id, step_name)
);
ALTER TABLE workflow_steps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "workflow_service_only" ON workflow_steps FOR ALL USING (true);
CREATE INDEX idx_workflow_steps_workflow ON workflow_steps(workflow_id, step_order);
CREATE INDEX idx_workflow_steps_status ON workflow_steps(status) WHERE status IN ('running', 'failed');
COMMENT ON TABLE workflow_steps IS 'Saga pattern: tracks multi-step workflows. Each step records input/output for compensation on failure.';
CREATE TRIGGER trg_workflow_steps_updated_at BEFORE UPDATE ON workflow_steps FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS job_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending',
  priority int NOT NULL DEFAULT 0,
  attempts int NOT NULL DEFAULT 0,
  max_attempts int NOT NULL DEFAULT 3,
  last_error text,
  next_retry_at timestamptz,
  locked_by text,
  locked_at timestamptz,
  organization_id uuid REFERENCES organizations(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  completed_at timestamptz,
  CONSTRAINT job_queue_status_check CHECK (status IN ('pending', 'running', 'completed', 'failed', 'dead'))
);
ALTER TABLE job_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "job_queue_service_only" ON job_queue FOR ALL USING (true);
CREATE INDEX idx_job_queue_pending ON job_queue(next_retry_at, priority DESC) WHERE status = 'pending';
CREATE INDEX idx_job_queue_locked ON job_queue(locked_at) WHERE status = 'running';
COMMENT ON TABLE job_queue IS 'Retry with exponential backoff. Workers use SELECT FOR UPDATE SKIP LOCKED.';
CREATE TRIGGER trg_job_queue_updated_at BEFORE UPDATE ON job_queue FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION acquire_next_job(p_job_type text, p_worker_id text)
RETURNS job_queue LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_job job_queue;
BEGIN
  SELECT * INTO v_job FROM job_queue
  WHERE job_type = p_job_type AND status = 'pending' AND (next_retry_at IS NULL OR next_retry_at <= now())
  ORDER BY priority DESC, created_at ASC LIMIT 1 FOR UPDATE SKIP LOCKED;
  IF v_job.id IS NULL THEN RETURN NULL; END IF;
  UPDATE job_queue SET status = 'running', locked_by = p_worker_id, locked_at = now(), attempts = attempts + 1 WHERE id = v_job.id RETURNING * INTO v_job;
  RETURN v_job;
END;
$$;

CREATE OR REPLACE FUNCTION complete_job(p_job_id uuid, p_success boolean, p_error text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_success THEN
    UPDATE job_queue SET status = 'completed', completed_at = now(), locked_by = NULL WHERE id = p_job_id;
  ELSE
    UPDATE job_queue SET status = CASE WHEN attempts >= max_attempts THEN 'dead' ELSE 'pending' END, last_error = p_error, locked_by = NULL, locked_at = NULL, next_retry_at = CASE WHEN attempts < max_attempts THEN now() + ((power(2, attempts)) * interval '30 seconds') ELSE NULL END WHERE id = p_job_id;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS request_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text NOT NULL,
  method text,
  path text,
  status_code int,
  duration_ms int,
  actor_person_id uuid,
  organization_id uuid,
  error_code text,
  error_message text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
ALTER TABLE request_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "request_log_service_only" ON request_log FOR ALL USING (true);
CREATE INDEX idx_request_log_created ON request_log(created_at DESC);
CREATE INDEX idx_request_log_errors ON request_log(created_at DESC) WHERE error_code IS NOT NULL;
CREATE INDEX idx_request_log_slow ON request_log(duration_ms DESC) WHERE duration_ms > 500;
COMMENT ON TABLE request_log IS 'API request observability. Enables error rate, p95 latency, slow query tracking.';

CREATE OR REPLACE VIEW v_api_health_1h AS
SELECT date_trunc('hour', created_at) as hour, count(*) as total_requests, count(*) FILTER (WHERE error_code IS NOT NULL) as error_count, round(100.0 * count(*) FILTER (WHERE error_code IS NOT NULL) / GREATEST(count(*), 1), 2) as error_rate_pct, percentile_cont(0.50) WITHIN GROUP (ORDER BY duration_ms) as p50_ms, percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_ms, percentile_cont(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99_ms, max(duration_ms) as max_ms FROM request_log WHERE created_at > now() - interval '24 hours' GROUP BY 1 ORDER BY 1 DESC;
ALTER VIEW v_api_health_1h SET (security_invoker = on);;
