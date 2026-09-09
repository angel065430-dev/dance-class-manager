# Dance Class Manager — Staging Git Handoff (2026-09-09)

## Git baseline

- Repository: `angel065430-dev/dance-class-manager`
- Baseline branch: `master`
- Baseline commit: `3af20b437bebf481c470c8e95ee6a0cd427523a7`
- Handoff branch: `codex/auth-hardening-staging`
- Canonical migrations 01–17 remain unchanged.
- Migrations 15–19 and the four Auth Edge Functions are included in this handoff.

## Staging environment

- Supabase project ref: `dmoovsjerpeaoloidivf`
- Vercel project: `dance-class-manager-staging`
- Preview URL: `https://dance-class-manager-staging-1b2btp7mi-angel065430-8978.vercel.app`
- Staging is invitation-only and displays `封閉測試，請勿付款` instead of real collection details.
- No password, API key, token, PIN, invitation code, service-role key, or production data is stored in this document.

## Completed verification

- Local: type-check, ESLint, 34 Vitest tests, production build, and four Playwright E2E tests passed.
- Staging database: migrations 01–19 applied; Auth security catalog checks passed.
- Staging backend smoke: admin authorization, invitation creation, invited signup, fresh student login, invalid-invitation rejection, course browsing, two-course full-term registration, registrations/payment view, and non-admin rejection passed.
- HTTPS: public preview access, student login, and closed-test payment warning were verified.
- The canonical router now redirects `/admin` to the protected admin registrations route; unauthenticated visitors are then sent to `/admin/login` by the existing guard.

## Still to verify

- Re-run the HTTPS admin path after the canonical `/admin` redirect is deployed: `/admin` → admin login → dashboard → invitation creation.
- The preview URL may change on the next Vercel deployment; retrieve the current READY deployment before distributing it.

## Production-readiness exclusions

This staging handoff is not ready for real payments or general production enrollment. The following remain separate future work:

- 48-hour payment deadline and overdue reminders.
- Releasing capacity only after administrator confirmation.
- Priority enrollment.
- Server-calculated multi-class full-term discounts with an order snapshot.
- A production self-registration design for genuinely new students that prevents phone-number-only takeover of existing student identities.

Tonight's closed test must remain invitation-only. Do not deploy this branch to the existing production Vercel project.

## Safe continuation on another computer

1. Preserve any local work before switching branches (`git status` first; commit or stash only your own changes).
2. Fetch from `origin`, then create a local tracking branch for `origin/codex/auth-hardening-staging`.
3. Create local environment files from the example templates and enter staging values locally; never commit them.
4. Confirm the Supabase project ref is `dmoovsjerpeaoloidivf` before any remote command.
5. Do not run database reset, migration repair, migration replay, `--prune`, or a production deployment.
