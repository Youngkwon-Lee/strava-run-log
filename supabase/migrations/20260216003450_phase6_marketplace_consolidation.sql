-- Phase 6: Marketplace consolidation (marketplace_ prefix to avoid collision)
ALTER TABLE unified_patient_requests RENAME TO marketplace_requests;
ALTER TABLE unified_therapist_proposals RENAME TO marketplace_proposals;
ALTER TABLE unified_appointments RENAME TO marketplace_appointments;
ALTER TABLE matching_requests_private RENAME TO marketplace_requests_private;

-- DROP matching_requests (empty, now replaced)
DROP TABLE IF EXISTS matching_requests CASCADE;;
