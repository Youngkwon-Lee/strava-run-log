-- Add applicable_expert_types to 5 library tables
-- Default: all 5 expert types (show to everyone by default)

ALTER TABLE assessment_form_templates
  ADD COLUMN applicable_expert_types text[]
  DEFAULT ARRAY['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach'];

ALTER TABLE special_tests
  ADD COLUMN applicable_expert_types text[]
  DEFAULT ARRAY['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach'];

ALTER TABLE clinical_guidelines
  ADD COLUMN applicable_expert_types text[]
  DEFAULT ARRAY['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach'];

ALTER TABLE exercise_protocols
  ADD COLUMN applicable_expert_types text[]
  DEFAULT ARRAY['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach'];

ALTER TABLE condition_library
  ADD COLUMN applicable_expert_types text[]
  DEFAULT ARRAY['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach'];

-- GIN indexes for @> array containment queries
CREATE INDEX idx_assessment_form_templates_expert_types ON assessment_form_templates USING GIN (applicable_expert_types);
CREATE INDEX idx_special_tests_expert_types ON special_tests USING GIN (applicable_expert_types);
CREATE INDEX idx_clinical_guidelines_expert_types ON clinical_guidelines USING GIN (applicable_expert_types);
CREATE INDEX idx_exercise_protocols_expert_types ON exercise_protocols USING GIN (applicable_expert_types);
CREATE INDEX idx_condition_library_expert_types ON condition_library USING GIN (applicable_expert_types);;
