-- Student Auth hardening (append-only; do not edit earlier migrations).
-- 1. Account creation requires an admin-issued, phone-bound, expiring invitation.
-- 2. Login and signup throttles are consumed atomically under row locks.
-- 3. Admin invitation and PIN-reset audit writes are database transactions.

CREATE TABLE public.student_account_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_hash text NOT NULL CHECK (phone_hash ~ '^[0-9a-f]{64}$'),
  token_hash text NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'claimed', 'used', 'revoked')),
  claimed_by uuid,
  claimed_at timestamptz,
  used_at timestamptz,
  expires_at timestamptz NOT NULL,
  created_by uuid NOT NULL REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT student_account_invitations_expiry CHECK (expires_at > created_at)
);

CREATE INDEX idx_student_account_invitations_phone_hash
  ON public.student_account_invitations (phone_hash, status, expires_at);

ALTER TABLE public.student_account_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.student_account_invitations FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.student_account_invitations IS
  'Admin-issued, single-use student account invitations. Only SHA-256 phone/token fingerprints are stored; raw invitation codes and PINs are never persisted.';

CREATE OR REPLACE FUNCTION public.consume_student_signup_attempt(
  p_client_hash text,
  p_limit integer DEFAULT 10,
  p_window interval DEFAULT interval '1 hour'
)
RETURNS TABLE(allowed boolean, retry_after_seconds integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.student_signup_throttles%ROWTYPE;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_client_hash !~ '^[0-9a-f]{64}$' OR p_limit < 1 OR p_window <= interval '0' THEN
    RAISE EXCEPTION 'invalid throttle input' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.student_signup_throttles
    (client_hash, attempt_count, window_started_at, last_attempt_at)
  VALUES (p_client_hash, 0, v_now, v_now)
  ON CONFLICT (client_hash) DO NOTHING;

  SELECT * INTO STRICT v_row
  FROM public.student_signup_throttles
  WHERE client_hash = p_client_hash
  FOR UPDATE;

  IF v_now - v_row.window_started_at >= p_window THEN
    UPDATE public.student_signup_throttles
    SET attempt_count = 1, window_started_at = v_now, last_attempt_at = v_now
    WHERE client_hash = p_client_hash;
    RETURN QUERY SELECT true, 0;
  ELSIF v_row.attempt_count >= p_limit THEN
    UPDATE public.student_signup_throttles SET last_attempt_at = v_now
    WHERE client_hash = p_client_hash;
    RETURN QUERY SELECT false,
      GREATEST(1, ceil(extract(epoch FROM (v_row.window_started_at + p_window - v_now)))::integer);
  ELSE
    UPDATE public.student_signup_throttles
    SET attempt_count = v_row.attempt_count + 1, last_attempt_at = v_now
    WHERE client_hash = p_client_hash;
    RETURN QUERY SELECT true, 0;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.reserve_student_login_attempt(
  p_phone_hash text,
  p_limit integer DEFAULT 5,
  p_lock_duration interval DEFAULT interval '15 minutes'
)
RETURNS TABLE(allowed boolean, lock_on_failure boolean, retry_after_seconds integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.student_auth_throttles%ROWTYPE;
  v_now timestamptz := clock_timestamp();
  v_next_count integer;
  v_locked_until timestamptz;
BEGIN
  IF p_phone_hash !~ '^[0-9a-f]{64}$' OR p_limit < 1 OR p_lock_duration <= interval '0' THEN
    RAISE EXCEPTION 'invalid throttle input' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.student_auth_throttles
    (phone_hash, failed_login_count, locked_until, last_attempt_at)
  VALUES (p_phone_hash, 0, NULL, v_now)
  ON CONFLICT (phone_hash) DO NOTHING;

  SELECT * INTO STRICT v_row
  FROM public.student_auth_throttles
  WHERE phone_hash = p_phone_hash
  FOR UPDATE;

  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > v_now THEN
    RETURN QUERY SELECT false, true,
      GREATEST(1, ceil(extract(epoch FROM (v_row.locked_until - v_now)))::integer);
    RETURN;
  END IF;

  v_next_count := CASE WHEN v_row.locked_until IS NOT NULL THEN 1 ELSE v_row.failed_login_count + 1 END;
  v_locked_until := CASE WHEN v_next_count >= p_limit THEN v_now + p_lock_duration ELSE NULL END;

  UPDATE public.student_auth_throttles
  SET failed_login_count = v_next_count,
      locked_until = v_locked_until,
      last_attempt_at = v_now
  WHERE phone_hash = p_phone_hash;

  RETURN QUERY SELECT true, v_locked_until IS NOT NULL,
    CASE WHEN v_locked_until IS NULL THEN 0 ELSE ceil(extract(epoch FROM p_lock_duration))::integer END;
END;
$$;

CREATE OR REPLACE FUNCTION public.clear_student_login_failures(p_phone_hash text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_phone_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid phone hash' USING ERRCODE = '22023';
  END IF;
  UPDATE public.student_auth_throttles
  SET failed_login_count = 0, locked_until = NULL, last_attempt_at = clock_timestamp()
  WHERE phone_hash = p_phone_hash;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'throttle row missing' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_student_invitation(
  p_actor_id uuid,
  p_phone_hash text,
  p_token_hash text,
  p_expires_at timestamptz,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_actor_id AND role = 'admin') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_phone_hash !~ '^[0-9a-f]{64}$' OR p_token_hash !~ '^[0-9a-f]{64}$'
     OR p_expires_at <= clock_timestamp() OR p_expires_at > clock_timestamp() + interval '8 days' THEN
    RAISE EXCEPTION 'invalid invitation input' USING ERRCODE = '22023';
  END IF;

  UPDATE public.student_account_invitations
  SET status = 'revoked'
  WHERE phone_hash = p_phone_hash AND status IN ('active', 'claimed');

  INSERT INTO public.student_account_invitations
    (phone_hash, token_hash, expires_at, created_by)
  VALUES (p_phone_hash, p_token_hash, p_expires_at, p_actor_id)
  RETURNING id INTO v_id;

  INSERT INTO public.audit_logs
    (actor_id, actor_role, action, entity_type, entity_id, reason, after_data)
  VALUES
    (p_actor_id, 'admin', 'student_invitation_created', 'student_account_invitations', v_id,
     nullif(left(trim(coalesce(p_reason, '')), 200), ''), jsonb_build_object('expires_at', p_expires_at));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_student_invitation(
  p_phone_hash text,
  p_token_hash text,
  p_claim_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  SELECT id INTO v_id
  FROM public.student_account_invitations
  WHERE phone_hash = p_phone_hash AND token_hash = p_token_hash
    AND status = 'active' AND expires_at > clock_timestamp()
  FOR UPDATE;
  IF v_id IS NULL THEN RETURN NULL; END IF;
  UPDATE public.student_account_invitations
  SET status = 'claimed', claimed_by = p_claim_id, claimed_at = clock_timestamp()
  WHERE id = v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_student_invitation(p_invitation_id uuid, p_claim_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.student_account_invitations
  SET status = 'used', used_at = clock_timestamp()
  WHERE id = p_invitation_id AND status = 'claimed' AND claimed_by = p_claim_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'invitation claim mismatch' USING ERRCODE = 'P0001'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.release_student_invitation(p_invitation_id uuid, p_claim_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.student_account_invitations
  SET status = 'active', claimed_by = NULL, claimed_at = NULL
  WHERE id = p_invitation_id AND status = 'claimed' AND claimed_by = p_claim_id
    AND expires_at > clock_timestamp();
END;
$$;

CREATE OR REPLACE FUNCTION public.record_admin_pin_reset_event(
  p_actor_id uuid,
  p_student_id uuid,
  p_action text,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_actor_id AND role = 'admin') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_action NOT IN ('student_pin_reset_started', 'student_pin_reset_completed', 'student_pin_reset_failed') THEN
    RAISE EXCEPTION 'invalid audit action' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.audit_logs
    (actor_id, actor_role, action, entity_type, entity_id, reason)
  VALUES
    (p_actor_id, 'admin', p_action, 'profiles', p_student_id,
     nullif(left(trim(coalesce(p_reason, '')), 200), ''))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_student_signup_attempt(text, integer, interval) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reserve_student_login_attempt(text, integer, interval) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.clear_student_login_failures(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_create_student_invitation(uuid, text, text, timestamptz, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.claim_student_invitation(text, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_student_invitation(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_student_invitation(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_admin_pin_reset_event(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.consume_student_signup_attempt(text, integer, interval) TO service_role;
GRANT EXECUTE ON FUNCTION public.reserve_student_login_attempt(text, integer, interval) TO service_role;
GRANT EXECUTE ON FUNCTION public.clear_student_login_failures(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_create_student_invitation(uuid, text, text, timestamptz, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_student_invitation(text, text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_student_invitation(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_student_invitation(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_admin_pin_reset_event(uuid, uuid, text, text) TO service_role;
