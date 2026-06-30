ALTER TABLE persons ADD CONSTRAINT persons_client_kind_check CHECK (client_kind IS NULL OR client_kind IN ('medical_patient', 'wellness_client', 'mixed_client'));;
