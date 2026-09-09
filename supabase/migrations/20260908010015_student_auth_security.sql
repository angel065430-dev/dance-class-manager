-- 無 SMS 的學生帳號安全控制。只存手機號碼的 SHA-256 指紋與計數，不存 PIN。
CREATE TABLE public.student_auth_throttles (
  phone_hash text PRIMARY KEY CHECK (phone_hash ~ '^[0-9a-f]{64}$'),
  failed_login_count integer NOT NULL DEFAULT 0 CHECK (failed_login_count >= 0),
  locked_until timestamptz,
  last_attempt_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.student_auth_throttles ENABLE ROW LEVEL SECURITY;
-- 無 RLS policy：瀏覽器與一般 JWT 均不可直接讀寫；僅 Edge Function service role 使用。

REVOKE ALL ON TABLE public.student_auth_throttles FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.student_auth_throttles IS
  'Phone+PIN 登入的伺服器端失敗計數與暫時鎖定。phone_hash 為 E.164 手機 SHA-256；絕不儲存 PIN。';

CREATE TABLE public.student_signup_throttles (
  client_hash text PRIMARY KEY CHECK (client_hash ~ '^[0-9a-f]{64}$'),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  window_started_at timestamptz NOT NULL DEFAULT now(),
  last_attempt_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.student_signup_throttles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.student_signup_throttles FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.student_signup_throttles IS
  '無 SMS 自助建立帳號的伺服器端節流。只存來源位址 SHA-256 指紋，不存 PIN。';
