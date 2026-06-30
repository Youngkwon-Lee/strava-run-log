-- Convert v_icf_core_set_details after icf_reference RLS hardening

alter view public.v_icf_core_set_details
  set (security_invoker = true);
