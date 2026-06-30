
ALTER TABLE clinical_content_registry
  DROP CONSTRAINT IF EXISTS clinical_content_registry_content_type_check;

ALTER TABLE clinical_content_registry
  ADD CONSTRAINT clinical_content_registry_content_type_check
    CHECK (content_type = ANY (ARRAY[
      'assessment_tool','special_test','exercise','treatment','approach','examination','education',
      'consent_template','education_material','rts_criteria','medication_interaction','rehab_protocol_extra'
    ]));
;
