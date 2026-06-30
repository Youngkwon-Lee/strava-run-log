-- Add 'functional_decline' to clinical_tasks task_type CHECK constraint
ALTER TABLE public.clinical_tasks DROP CONSTRAINT clinical_tasks_task_type_check;
ALTER TABLE public.clinical_tasks ADD CONSTRAINT clinical_tasks_task_type_check
  CHECK (task_type = ANY (ARRAY[
    'reassessment_due'::text,
    'care_plan_expiring'::text,
    'note_sign_off'::text,
    'discharge_review'::text,
    'intake_review'::text,
    'insurance_auth_needed'::text,
    'plateau_detected'::text,
    'overdue_follow_up'::text,
    'functional_decline'::text
  ]));;
