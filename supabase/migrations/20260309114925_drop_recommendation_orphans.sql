
-- Drop 4 orphan recommendation tables (have seed data but no code/function refs)
-- recommendations + recommendation_learning_log KEPT (active repos)
-- Flag tables (5) KEPT (seed reference data, low overhead)
DROP TABLE IF EXISTS recommendation_rules CASCADE;
DROP TABLE IF EXISTS condition_exercise_recommendations CASCADE;
DROP TABLE IF EXISTS symptom_test_recommendations CASCADE;
DROP TABLE IF EXISTS test_approach_recommendations CASCADE;

-- Drop 3 orphan functions that referenced flag/recommendation tables
DROP FUNCTION IF EXISTS calculate_chronicity_risk();
DROP FUNCTION IF EXISTS generate_client_explanation();
DROP FUNCTION IF EXISTS get_prognosis_guide();
;
