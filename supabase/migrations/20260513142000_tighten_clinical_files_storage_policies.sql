-- Purpose:
--   Tighten storage access for clinical-files bucket to match current app behavior.
--
-- Rationale:
--   Live bucket config shows `clinical-files` is private (`public=false`), but
--   storage.objects policies still allow broad `public` SELECT/INSERT/DELETE.
--   Current app request paths use privileged server-side repositories plus signed URLs,
--   so broad public storage object policies are wider than necessary.
--
-- Scope:
--   storage.objects policies for bucket_id = 'clinical-files'
--
-- Strategy:
--   Replace current public storage object access with service_role-only access.
--   App/API paths should continue to use server-side privileged clients and signed URLs.

DROP POLICY IF EXISTS "storage_clinical_read" ON storage.objects;
DROP POLICY IF EXISTS "storage_clinical_upload" ON storage.objects;
DROP POLICY IF EXISTS "storage_clinical_delete" ON storage.objects;
CREATE POLICY "storage_clinical_read_service_only"
  ON storage.objects
  AS PERMISSIVE FOR SELECT
  TO service_role
  USING (bucket_id = 'clinical-files');
CREATE POLICY "storage_clinical_upload_service_only"
  ON storage.objects
  AS PERMISSIVE FOR INSERT
  TO service_role
  WITH CHECK (
    bucket_id = 'clinical-files'
    AND (storage.foldername(name))[1] IS NOT NULL
  );
CREATE POLICY "storage_clinical_delete_service_only"
  ON storage.objects
  AS PERMISSIVE FOR DELETE
  TO service_role
  USING (bucket_id = 'clinical-files');
