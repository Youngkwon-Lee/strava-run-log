
-- Provider Referral Links (P1: Direct Connection)
CREATE TABLE IF NOT EXISTS provider_referral_links (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_person_id uuid NOT NULL REFERENCES persons(id),
  organization_id uuid REFERENCES organizations(id),

  slug            varchar(12) NOT NULL UNIQUE,
  link_type       text NOT NULL DEFAULT 'patient_intake'
    CHECK (link_type IN ('patient_intake', 'session_booking', 'assessment')),
  custom_message  text,

  expires_at      timestamptz,
  max_uses        int4,
  use_count       int4 DEFAULT 0,

  is_active       bool DEFAULT true,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

-- Referral Link Events (tracking)
CREATE TABLE IF NOT EXISTS referral_link_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id         uuid NOT NULL REFERENCES provider_referral_links(id) ON DELETE CASCADE,
  event_type      text NOT NULL
    CHECK (event_type IN ('click', 'register', 'intake_submit', 'match_created')),
  visitor_person_id uuid REFERENCES persons(id),
  created_at      timestamptz DEFAULT now()
);

-- Add connection_source + referral_link_id to care_relationship
ALTER TABLE care_relationship ADD COLUMN IF NOT EXISTS
  connection_source text DEFAULT 'manual'
    CHECK (connection_source IN ('manual', 'direct_link', 'open_bid', 'platform_match', 'org_invite'));

ALTER TABLE care_relationship ADD COLUMN IF NOT EXISTS
  referral_link_id uuid REFERENCES provider_referral_links(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referral_links_slug ON provider_referral_links(slug);
CREATE INDEX IF NOT EXISTS idx_referral_links_provider ON provider_referral_links(provider_person_id);
CREATE INDEX IF NOT EXISTS idx_referral_events_link ON referral_link_events(link_id);

-- RLS
ALTER TABLE provider_referral_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_link_events ENABLE ROW LEVEL SECURITY;

-- Provider can manage own links
CREATE POLICY "provider_own_links" ON provider_referral_links
  FOR ALL USING (provider_person_id = get_my_person_id());

-- Public can read active links by slug (for /join/[slug])
CREATE POLICY "public_read_active_links" ON provider_referral_links
  FOR SELECT USING (is_active = true);

-- Events: link owner can read
CREATE POLICY "provider_read_link_events" ON referral_link_events
  FOR SELECT USING (
    link_id IN (SELECT id FROM provider_referral_links WHERE provider_person_id = get_my_person_id())
  );

-- Events: service role inserts (public page tracking)
CREATE POLICY "service_insert_events" ON referral_link_events
  FOR INSERT WITH CHECK (true);
;
