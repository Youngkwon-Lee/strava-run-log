-- ============================================
-- 1. invoice_line_items에 provider_person_id 추가 (비정규화)
-- ============================================
ALTER TABLE invoice_line_items
  ADD COLUMN provider_person_id uuid REFERENCES persons(id);

CREATE INDEX idx_invoice_line_items_provider ON invoice_line_items(provider_person_id);

COMMENT ON COLUMN invoice_line_items.provider_person_id IS 'Denormalized from encounters.provider_person_id for fast provider revenue queries';

-- Auto-populate from encounter when available
UPDATE invoice_line_items ili
SET provider_person_id = e.provider_person_id
FROM encounters e
WHERE ili.encounter_id = e.id
  AND ili.provider_person_id IS NULL
  AND e.provider_person_id IS NOT NULL;

-- ============================================
-- 2. Trigger to auto-set provider_person_id on INSERT
-- ============================================
CREATE OR REPLACE FUNCTION set_line_item_provider()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NEW.provider_person_id IS NULL AND NEW.encounter_id IS NOT NULL THEN
    SELECT provider_person_id INTO NEW.provider_person_id
    FROM encounters WHERE id = NEW.encounter_id;
  END IF;
  RETURN NEW;
END;
$fn$;

CREATE TRIGGER trg_set_line_item_provider
  BEFORE INSERT ON invoice_line_items
  FOR EACH ROW
  EXECUTE FUNCTION set_line_item_provider();

-- ============================================
-- 3. Provider revenue view (self-scope)
-- ============================================
CREATE VIEW v_provider_revenue AS
SELECT
  ili.provider_person_id,
  i.organization_id,
  -- 30 days
  COUNT(*) FILTER (WHERE i.invoice_date >= CURRENT_DATE - 30) AS line_items_30d,
  COALESCE(SUM(ili.line_amount) FILTER (WHERE i.invoice_date >= CURRENT_DATE - 30), 0) AS revenue_30d,
  -- 7 days
  COUNT(*) FILTER (WHERE i.invoice_date >= CURRENT_DATE - 7) AS line_items_7d,
  COALESCE(SUM(ili.line_amount) FILTER (WHERE i.invoice_date >= CURRENT_DATE - 7), 0) AS revenue_7d,
  -- Monthly
  COUNT(*) FILTER (WHERE i.invoice_date >= date_trunc('month', CURRENT_DATE)) AS line_items_month,
  COALESCE(SUM(ili.line_amount) FILTER (WHERE i.invoice_date >= date_trunc('month', CURRENT_DATE)), 0) AS revenue_month,
  -- All time
  COUNT(*) AS line_items_total,
  COALESCE(SUM(ili.line_amount), 0) AS revenue_total
FROM invoice_line_items ili
JOIN invoices i ON ili.invoice_id = i.id
WHERE ili.provider_person_id IS NOT NULL
  AND i.status IN ('paid', 'sent', 'finalized')
  AND i.deleted_at IS NULL
GROUP BY ili.provider_person_id, i.organization_id;

COMMENT ON VIEW v_provider_revenue IS 'Provider-level revenue attribution. Clinicians see own row only (via RLS on underlying tables). Admins see org-wide.';

-- ============================================
-- 4. Provider productivity view (self-scope)
-- ============================================
CREATE VIEW v_provider_productivity AS
SELECT
  e.provider_person_id,
  e.organization_id,
  -- Encounters
  COUNT(*) FILTER (WHERE e.period_start >= CURRENT_DATE - 30) AS encounters_30d,
  COUNT(*) FILTER (WHERE e.period_start >= CURRENT_DATE - 7) AS encounters_7d,
  COUNT(DISTINCT e.subject_person_id) FILTER (WHERE e.period_start >= CURRENT_DATE - 30) AS unique_patients_30d,
  -- Notes
  (SELECT COUNT(*) FROM encounter_notes en WHERE en.organization_id = e.organization_id AND en.person_id = e.provider_person_id AND en.status = 'finalized' AND en.created_at >= CURRENT_DATE - 30) AS finalized_notes_30d,
  -- Outcomes (MCID achieved)
  (SELECT COUNT(*) FROM person_outcomes po WHERE po.organization_id = e.organization_id AND po.subject_person_id IN (SELECT DISTINCT e2.subject_person_id FROM encounters e2 WHERE e2.provider_person_id = e.provider_person_id AND e2.organization_id = e.organization_id) AND po.mcid_pain_achieved = true) AS mcid_pain_achieved_count,
  (SELECT COUNT(*) FROM person_outcomes po WHERE po.organization_id = e.organization_id AND po.subject_person_id IN (SELECT DISTINCT e2.subject_person_id FROM encounters e2 WHERE e2.provider_person_id = e.provider_person_id AND e2.organization_id = e.organization_id) AND po.mcid_function_achieved = true) AS mcid_function_achieved_count
FROM encounters e
WHERE e.deleted_at IS NULL
  AND e.provider_person_id IS NOT NULL
GROUP BY e.provider_person_id, e.organization_id;

COMMENT ON VIEW v_provider_productivity IS 'Provider-level productivity metrics: encounters, patients, notes, outcomes. For self-dashboard and admin comparison.';
;
