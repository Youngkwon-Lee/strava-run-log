-- P1 follow-up: add covering index for automation_rules foreign key.

create index if not exists idx_automation_rules_created_by
  on public.automation_rules (created_by);
