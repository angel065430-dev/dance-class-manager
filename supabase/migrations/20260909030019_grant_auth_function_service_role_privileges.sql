-- The Auth Edge Functions use a service-role Supabase client for narrowly
-- scoped profile/role lookups and student provisioning.  Hosted projects still
-- require table privileges before BYPASSRLS can take effect.

GRANT SELECT ON TABLE public.profiles, public.user_roles TO service_role;
GRANT UPDATE ON TABLE public.profiles TO service_role;
GRANT INSERT ON TABLE public.user_roles TO service_role;

-- Sensitive tables remain callable only through the SECURITY DEFINER RPCs
-- granted in migration 17; do not expose direct access to any client role.
REVOKE ALL ON TABLE
  public.student_auth_throttles,
  public.student_signup_throttles,
  public.student_account_invitations
FROM PUBLIC, anon, authenticated;
