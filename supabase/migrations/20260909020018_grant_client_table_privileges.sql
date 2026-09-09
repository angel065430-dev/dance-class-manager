-- Hosted projects do not inherit the local development role grants for tables
-- created by migrations.  Table privileges are required before PostgreSQL can
-- evaluate the existing RLS policies, so grant only the operations represented
-- by those policies.  RLS remains the row-level security boundary.

GRANT SELECT ON TABLE
  public.venues,
  public.terms,
  public.classes,
  public.class_sessions
TO anon;

GRANT SELECT ON TABLE
  public.profiles,
  public.user_roles,
  public.venues,
  public.terms,
  public.classes,
  public.class_sessions,
  public.audit_logs,
  public.idempotency_keys,
  public.orders,
  public.registrations,
  public.venue_payment_settings
TO authenticated;

GRANT UPDATE ON TABLE public.profiles TO authenticated;

GRANT INSERT, UPDATE, DELETE ON TABLE
  public.user_roles,
  public.venues,
  public.terms,
  public.classes,
  public.class_sessions,
  public.venue_payment_settings
TO authenticated;

GRANT INSERT ON TABLE public.idempotency_keys TO authenticated;

-- Auth secret/throttle tables intentionally stay inaccessible to client roles.
REVOKE ALL ON TABLE
  public.student_auth_throttles,
  public.student_signup_throttles,
  public.student_account_invitations
FROM PUBLIC, anon, authenticated;
