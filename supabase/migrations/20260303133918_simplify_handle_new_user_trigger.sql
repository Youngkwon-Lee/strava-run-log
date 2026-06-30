
-- 함수 교체 (person만 생성)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_first_name TEXT;
  v_user_type TEXT;
  v_expert_type TEXT;
  v_app_context TEXT;
BEGIN
  v_app_context := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'app_context'), ''), 'platform-web');
  v_first_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    split_part(NEW.email, '@', 1)
  );
  v_user_type := CASE
    WHEN v_app_context IN ('patient-pwa', 'patient-app') THEN 'client'
    ELSE 'professional'
  END;
  v_expert_type := CASE
    WHEN v_user_type = 'professional' THEN COALESCE(
      NULLIF(TRIM(NEW.raw_user_meta_data->>'expert_type'), ''), 'physiotherapist')
    ELSE NULL
  END;

  -- Person만 생성 (org/member는 앱에서 RPC로 처리)
  INSERT INTO public.persons (
    auth_user_id, email, first_name,
    user_type, expert_type, source_type, onboarding_status
  ) VALUES (
    NEW.id, NEW.email, v_first_name,
    v_user_type, v_expert_type, 'self_registered', 'pending'
  )
  ON CONFLICT (auth_user_id) DO NOTHING;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- 절대 auth.users INSERT를 실패시키지 않음
  INSERT INTO signup_repair_queue (auth_user_id, error_context, error_message, metadata)
  VALUES (NEW.id, 'handle_new_user', SQLERRM, jsonb_build_object('email', NEW.email))
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

-- 트리거 바인딩 (현재 없으므로 새로 생성)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
;
