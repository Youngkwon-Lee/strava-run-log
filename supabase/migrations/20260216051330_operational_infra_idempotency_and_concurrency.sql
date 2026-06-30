-- ============================================
-- 1. IDEMPOTENCY: Generic API idempotency table
-- ============================================
CREATE TABLE IF NOT EXISTS api_idempotency (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL,
  resource_type text NOT NULL,
  resource_id uuid,
  request_hash text,
  response_status int,
  response_body jsonb,
  created_by uuid REFERENCES persons(id),
  organization_id uuid REFERENCES organizations(id),
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT now() + interval '24 hours',
  CONSTRAINT api_idempotency_key_unique UNIQUE (idempotency_key)
);
ALTER TABLE api_idempotency ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_only" ON api_idempotency FOR ALL USING (true);
CREATE INDEX idx_api_idempotency_expires ON api_idempotency(expires_at);
COMMENT ON TABLE api_idempotency IS 'API-level idempotency: prevents duplicate creates on client retry. App sends X-Idempotency-Key header, checks here before INSERT.';

CREATE OR REPLACE FUNCTION cleanup_expired_idempotency_keys()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  DELETE FROM api_idempotency WHERE expires_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ============================================
-- 2. CONCURRENCY: Booking overlap prevention
-- ============================================
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Function to validate no booking overlap for same provider
CREATE OR REPLACE FUNCTION validate_booking_no_overlap()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.status IN ('pending', 'confirmed') THEN
    IF EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id != NEW.id
        AND b.provider_person_id = NEW.provider_person_id
        AND b.status IN ('pending', 'confirmed')
        AND tstzrange(b.scheduled_at, b.scheduled_at + (b.duration_minutes || ' minutes')::interval)
           && tstzrange(NEW.scheduled_at, NEW.scheduled_at + (NEW.duration_minutes || ' minutes')::interval)
    ) THEN
      RAISE EXCEPTION 'Booking overlap: provider % already has a booking at this time', NEW.provider_person_id
        USING ERRCODE = 'exclusion_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_booking_no_overlap
  BEFORE INSERT OR UPDATE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION validate_booking_no_overlap();

COMMENT ON FUNCTION validate_booking_no_overlap() IS 'Prevents double-booking same provider at overlapping times. Only checks pending/confirmed.';

-- ============================================
-- 3. CONCURRENCY: Encounter optimistic locking
-- ============================================
ALTER TABLE encounters ADD COLUMN IF NOT EXISTS version int NOT NULL DEFAULT 1;
COMMENT ON COLUMN encounters.version IS 'Optimistic locking: app must send current version on UPDATE, trigger rejects stale writes.';

CREATE OR REPLACE FUNCTION check_encounter_version()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.version != OLD.version + 1 THEN
    RAISE EXCEPTION 'Stale encounter update: expected version %, got %', OLD.version + 1, NEW.version
      USING ERRCODE = 'serialization_failure';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_encounter_version_check
  BEFORE UPDATE ON encounters
  FOR EACH ROW
  WHEN (NEW.version IS DISTINCT FROM OLD.version)
  EXECUTE FUNCTION check_encounter_version();;
