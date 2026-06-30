
-- P1-1: Add risk_domain mapping to category_registry
-- Maps observation categories → risk engine domains (SSOT for CATEGORY_TO_DOMAIN)
ALTER TABLE category_registry
  ADD COLUMN risk_domain text,
  ADD COLUMN risk_domain_weight numeric(4,3) DEFAULT 0.05;

-- Populate risk_domain mappings (matches current hardcoded CATEGORY_TO_DOMAIN)
UPDATE category_registry SET risk_domain = 'pain', risk_domain_weight = 0.280 WHERE code = 'pain';
UPDATE category_registry SET risk_domain = 'pain', risk_domain_weight = 0.280 WHERE code = 'sensory-pain';
UPDATE category_registry SET risk_domain = 'function', risk_domain_weight = 0.270 WHERE code = 'disability';
UPDATE category_registry SET risk_domain = 'function', risk_domain_weight = 0.270 WHERE code = 'functional';
UPDATE category_registry SET risk_domain = 'function', risk_domain_weight = 0.270 WHERE code = 'self-care';
UPDATE category_registry SET risk_domain = 'fall_risk', risk_domain_weight = 0.220 WHERE code = 'balance';
UPDATE category_registry SET risk_domain = 'mobility', risk_domain_weight = 0.060 WHERE code = 'mobility';
UPDATE category_registry SET risk_domain = 'mobility', risk_domain_weight = 0.060 WHERE code = 'gait';
UPDATE category_registry SET risk_domain = 'cognitive', risk_domain_weight = 0.020 WHERE code = 'cognitive';
UPDATE category_registry SET risk_domain = 'psychosocial', risk_domain_weight = 0.130 WHERE code = 'psychological';
UPDATE category_registry SET risk_domain = 'psychosocial', risk_domain_weight = 0.130 WHERE code = 'mental';
UPDATE category_registry SET risk_domain = 'adl', risk_domain_weight = 0.020 WHERE code = 'geriatric';

-- Unmapped categories (null risk_domain = skip in risk engine, same as current behavior)
-- cardiopulmonary, coordination, endurance, flexibility, neurological, neuromusculoskeletal,
-- pediatric, posture, proprioception, quality-of-life, sports, stabilization, strength, strengthening, stretching

COMMENT ON COLUMN category_registry.risk_domain IS 'Maps to DomainRisk.domain in risk-engine.ts. NULL = not scored in risk engine.';
COMMENT ON COLUMN category_registry.risk_domain_weight IS 'Weight for composite risk scoring (0-1). Domains with same risk_domain share the weight.';
;
