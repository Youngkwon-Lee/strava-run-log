-- P1 follow-up: add covering index for clinical_insights foreign key.

create index if not exists idx_clinical_insights_created_by
  on public.clinical_insights (created_by);;
