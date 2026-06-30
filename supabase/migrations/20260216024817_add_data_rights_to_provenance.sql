-- data_provenance에 data_rights 컬럼 추가
ALTER TABLE data_provenance ADD COLUMN data_rights text DEFAULT 'org_owned';

ALTER TABLE data_provenance ADD CONSTRAINT data_provenance_data_rights_check
  CHECK (data_rights IS NULL OR data_rights IN ('client_owned','org_owned','shared','platform_owned'));

COMMENT ON COLUMN data_provenance.data_rights IS 'Data ownership: client_owned (PGHD/self-report), org_owned (clinical), shared (cross-org consent), platform_owned (system-generated).';;
