-- Drop stale workflow helper residue verified in Wave 4C review.
-- Preconditions verified on 2026-03-15:
--   - public.update_workflow_updated_at() exists in live `public`
--   - non-internal trigger attachments = 0
--   - no live `workflow_stage` column exists in `public`
--   - no exact-name repo runtime call sites were found
--   - no function/view/matview references were found

drop function if exists public.update_workflow_updated_at();;
