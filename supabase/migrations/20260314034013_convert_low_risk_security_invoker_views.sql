alter view public.recommendation_exercises
  set (security_invoker = true);

alter view public.exercise_promotion_candidates
  set (security_invoker = true);

alter view public.v_protocol_exercise_mapping
  set (security_invoker = true);

alter view public.v_ai_acceptance_rate
  set (security_invoker = true);

alter view public.v_episode_summary
  set (security_invoker = true);

alter view public.v_class_analytics
  set (security_invoker = true);;
