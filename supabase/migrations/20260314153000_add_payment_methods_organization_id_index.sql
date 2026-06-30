-- P1 follow-up: add covering index for payment_methods foreign key.

create index if not exists idx_payment_methods_organization_id
  on public.payment_methods (organization_id);
