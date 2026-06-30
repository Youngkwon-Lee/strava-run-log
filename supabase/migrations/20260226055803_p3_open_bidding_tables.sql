
-- ============================================================
-- P3 Open Bidding: expert_bids + credit_ledger + match_results 확장
-- ============================================================

-- 1. match_results에 Open Bidding 컬럼 추가
ALTER TABLE match_results
  ADD COLUMN IF NOT EXISTS matching_mode text NOT NULL DEFAULT 'direct'
    CHECK (matching_mode IN ('direct', 'ai_recommend', 'open_bid')),
  ADD COLUMN IF NOT EXISTS case_summary text,
  ADD COLUMN IF NOT EXISTS bid_deadline timestamptz,
  ADD COLUMN IF NOT EXISTS max_bids int4 DEFAULT 5,
  ADD COLUMN IF NOT EXISTS is_anonymous bool DEFAULT true;

-- 2. expert_bids 테이블
CREATE TABLE IF NOT EXISTS expert_bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_result_id uuid NOT NULL REFERENCES match_results(id) ON DELETE CASCADE,
  expert_person_id uuid NOT NULL REFERENCES persons(id),
  proposed_fee int4,
  proposed_mode text CHECK (proposed_mode IN ('in_clinic', 'home_visit', 'remote', 'hybrid')),
  proposed_start date,
  cover_message text NOT NULL,
  estimated_sessions int4,
  approach_keys text[],
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'viewed', 'shortlisted', 'accepted', 'rejected', 'withdrawn', 'expired')),
  credits_charged int4 DEFAULT 0,
  credits_refunded bool DEFAULT false,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  viewed_at timestamptz,
  responded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_result_id, expert_person_id)
);

-- 3. credit_ledger 테이블 (전문가 크레딧)
CREATE TABLE IF NOT EXISTS credit_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id uuid NOT NULL REFERENCES persons(id),
  transaction_type text NOT NULL
    CHECK (transaction_type IN ('purchase', 'bid_charge', 'refund', 'bonus', 'expire', 'signup_bonus')),
  amount int4 NOT NULL,
  balance_after int4 NOT NULL,
  reference_id uuid,
  reference_type text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 4. 인덱스
CREATE INDEX IF NOT EXISTS idx_expert_bids_match_result ON expert_bids(match_result_id);
CREATE INDEX IF NOT EXISTS idx_expert_bids_expert ON expert_bids(expert_person_id);
CREATE INDEX IF NOT EXISTS idx_expert_bids_status ON expert_bids(status);
CREATE INDEX IF NOT EXISTS idx_credit_ledger_person ON credit_ledger(person_id);
CREATE INDEX IF NOT EXISTS idx_match_results_mode ON match_results(matching_mode) WHERE matching_mode = 'open_bid';
CREATE INDEX IF NOT EXISTS idx_match_results_deadline ON match_results(bid_deadline) WHERE bid_deadline IS NOT NULL;

-- 5. RLS
ALTER TABLE expert_bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_ledger ENABLE ROW LEVEL SECURITY;

-- expert_bids: 전문가 자기 입찰 CRUD + 환자 자기 케이스 입찰 조회
CREATE POLICY expert_bids_expert_select ON expert_bids FOR SELECT
  USING (expert_person_id = get_my_person_id());

CREATE POLICY expert_bids_expert_insert ON expert_bids FOR INSERT
  WITH CHECK (expert_person_id = get_my_person_id());

CREATE POLICY expert_bids_expert_update ON expert_bids FOR UPDATE
  USING (expert_person_id = get_my_person_id());

CREATE POLICY expert_bids_client_select ON expert_bids FOR SELECT
  USING (
    match_result_id IN (
      SELECT id FROM match_results WHERE client_person_id = get_my_person_id()
    )
  );

-- credit_ledger: 본인만
CREATE POLICY credit_ledger_own_select ON credit_ledger FOR SELECT
  USING (person_id = get_my_person_id());

CREATE POLICY credit_ledger_own_insert ON credit_ledger FOR INSERT
  WITH CHECK (person_id = get_my_person_id());

-- 6. updated_at 트리거
CREATE OR REPLACE TRIGGER set_updated_at_expert_bids
  BEFORE UPDATE ON expert_bids
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
;
