
-- Add reusable invite support
ALTER TABLE organization_invites
  ADD COLUMN IF NOT EXISTS max_uses INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS use_count INTEGER NOT NULL DEFAULT 0;

-- Existing used invites: set use_count = 1
UPDATE organization_invites SET use_count = 1 WHERE used_at IS NOT NULL AND use_count = 0;

COMMENT ON COLUMN organization_invites.max_uses IS 'Max number of times this invite can be used. 1 = single-use (default), >1 = reusable link';
COMMENT ON COLUMN organization_invites.use_count IS 'Current number of times this invite has been used';
;
