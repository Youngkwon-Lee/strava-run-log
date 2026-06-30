
-- P0 Fix #1: organization_members.dashboard_mode CHECK 확장
-- 기존: clinical | trainer (2개)
-- 변경: clinical | trainer | wellness | performance | owner (5개)
-- 기존 데이터: 'clinical' 3건, NULL 12건 → 무손실
ALTER TABLE public.organization_members
  DROP CONSTRAINT organization_members_dashboard_mode_check;

ALTER TABLE public.organization_members
  ADD CONSTRAINT organization_members_dashboard_mode_check
  CHECK (dashboard_mode = ANY (ARRAY[
    'clinical'::text,
    'trainer'::text,
    'wellness'::text,
    'performance'::text,
    'owner'::text
  ]));

-- P0 Fix #2: organizations.org_type CHECK 확장
-- 기존: clinic|hospital|gym|wellness_center|rehabilitation_center|sports_facility|marketplace|solo (8개)
-- 추가: sports_team|school_team|performance_center (3개)
-- 기존 데이터: clinic 9건, rehabilitation_center 1건 → 무손실
ALTER TABLE public.organizations
  DROP CONSTRAINT organizations_org_type_check;

ALTER TABLE public.organizations
  ADD CONSTRAINT organizations_org_type_check
  CHECK (org_type = ANY (ARRAY[
    'clinic'::text,
    'hospital'::text,
    'gym'::text,
    'wellness_center'::text,
    'rehabilitation_center'::text,
    'sports_facility'::text,
    'marketplace'::text,
    'solo'::text,
    'sports_team'::text,
    'school_team'::text,
    'performance_center'::text
  ]));
;
