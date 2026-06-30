-- P1 follow-up: add covering indexes for prompt evaluation/template foreign keys.

create index if not exists idx_prompt_evaluation_results_sample_id
  on public.prompt_evaluation_results (sample_id);

create index if not exists idx_prompt_evaluation_samples_created_by
  on public.prompt_evaluation_samples (created_by);

create index if not exists idx_prompt_templates_created_by
  on public.prompt_templates (created_by);;
