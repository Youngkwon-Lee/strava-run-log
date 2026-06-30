-- Remove stale public functions that Supabase db lint reports as broken.
-- These functions reference tables/columns/types from retired prototypes and
-- are not called by the application codebase. Warning-only functions are kept.

do $$
declare
  routine regprocedure;
begin
  perform set_config('search_path', 'public, extensions, pg_catalog', true);

  for routine in
    select p.oid::regprocedure
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(array[
        'acknowledge_red_flag_alert',
        'calculate_chronicity_risk',
        'calculate_client_outcome',
        'calculate_delta_density',
        'calculate_fleiss_kappa',
        'cleanup_completed_sync_queue',
        'cleanup_expired_cache',
        'convert_old_assessment_items',
        'create_matching_request',
        'create_observations_from_assessment_result',
        'create_workflow_snapshot',
        'find_exercise_path',
        'find_matching_experts',
        'find_similar_documents',
        'generate_embedding_text_for_exercise',
        'generate_invite_code',
        'generate_match_candidates',
        'get_active_licenses',
        'get_booking_state_from_events',
        'get_client_metrics',
        'get_client_prognosis_context',
        'get_code_validation_rules',
        'get_exercise_filter_stats',
        'get_icf_codes_for_condition',
        'get_mlops_dashboard_metrics',
        'get_policy_recommendations',
        'get_realtime_sync_status',
        'get_recommended_tests_by_pain_location',
        'get_related_exercises',
        'get_similar_labels_for_policy',
        'get_stt_training_stats',
        'get_task_event_history',
        'get_user_project_role',
        'get_vector_category_stats',
        'get_vector_index_stats',
        'get_vla_session_summary',
        'get_vlm_acceptance_rate',
        'get_workflow_audit_summary',
        'has_license',
        'increment_search_keyword_usage',
        'increment_usage_count',
        'initialize_research_workflow',
        'interpret_score_change',
        'interpret_multiple_score_changes',
        'is_org_medical_facility',
        'log_workflow_event',
        'match_documents_by_date',
        'match_multi_query',
        'match_with_metadata',
        'normalize_client_conditions',
        'prevent_guideline_duplication',
        'reconstruct_workflow_state',
        'respond_to_match_candidate',
        'search_by_date_range',
        'search_by_metadata',
        'search_medical_codes',
        'search_multimodal_cases',
        'search_mvp_vectors',
        'search_similar_medical_images',
        'search_similar_mris',
        'search_similar_xrays',
        'select_expert_from_candidates',
        'suggest_mapping_improvements',
        'update_policy_success_rate',
        'update_research_task',
        'user_has_permission',
        'validate_scenario_quality',
        'vector_search_category_stats'
      ]::name[])
  loop
    execute format('drop function if exists %s', routine);
  end loop;
end
$$;
