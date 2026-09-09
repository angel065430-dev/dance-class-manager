-- Run against an isolated local database after all migrations.
-- This verifies that 20 calls cannot lose increments: the row-locked function
-- must accept exactly the configured limit and retain an exact count.
BEGIN;

DO $$
DECLARE
  v_hash text := repeat('a', 64);
  v_allowed integer := 0;
  v_result record;
BEGIN
  DELETE FROM public.student_signup_throttles WHERE client_hash = v_hash;
  FOR i IN 1..20 LOOP
    SELECT * INTO v_result FROM public.consume_student_signup_attempt(v_hash, 10, interval '1 hour');
    IF v_result.allowed THEN v_allowed := v_allowed + 1; END IF;
  END LOOP;
  IF v_allowed <> 10 THEN RAISE EXCEPTION 'expected 10 allowed attempts, got %', v_allowed; END IF;
  IF (SELECT attempt_count FROM public.student_signup_throttles WHERE client_hash = v_hash) <> 10 THEN
    RAISE EXCEPTION 'signup count lost or exceeded limit';
  END IF;
END;
$$;

DO $$
DECLARE
  v_hash text := repeat('b', 64);
  v_result record;
BEGIN
  DELETE FROM public.student_auth_throttles WHERE phone_hash = v_hash;
  FOR i IN 1..5 LOOP
    SELECT * INTO v_result FROM public.reserve_student_login_attempt(v_hash, 5, interval '15 minutes');
    IF NOT v_result.allowed THEN RAISE EXCEPTION 'attempt % should be reserved', i; END IF;
  END LOOP;
  SELECT * INTO v_result FROM public.reserve_student_login_attempt(v_hash, 5, interval '15 minutes');
  IF v_result.allowed THEN RAISE EXCEPTION 'sixth attempt must be locked'; END IF;
END;
$$;

ROLLBACK;
