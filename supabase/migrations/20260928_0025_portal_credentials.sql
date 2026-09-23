-- ====================================================================
-- Migration 0025: Admin-editable portal passwords
--
-- Login credentials for the Admin Orchestrator / POS 1 staff / POS 2
-- staff portals were previously fixed at build time via Vite env vars
-- (VITE_ADMIN_PASSWORD / VITE_POS1_STAFF_PASSWORD / VITE_POS2_STAFF_PASSWORD),
-- with no way to change a password without editing .env and redeploying.
--
-- This table lets the admin change any of the 3 passwords from inside
-- the app (Dashboard > Staff & Memberships). A NULL password_override
-- means "keep using the .env default" for that account; Portal IDs are
-- unaffected and still come from .env.
--
-- Note on trust model: like every other table in this schema, RLS here
-- is permissive (USING (TRUE)) because there is no real Supabase Auth
-- session for the POS portal logins -- this app authenticates client-side
-- against a fixed credential set, the same trust level as the .env
-- passwords it replaces (both are readable by anyone who inspects the
-- client, since the anon key is public). This is not a security upgrade,
-- just a way to change the password without a redeploy.
-- ====================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.portal_credentials (
  role_key TEXT PRIMARY KEY CHECK (role_key IN ('admin', 'pos1_staff', 'pos2_staff')),
  password_override TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.portal_credentials (role_key, password_override)
VALUES ('admin', NULL), ('pos1_staff', NULL), ('pos2_staff', NULL)
ON CONFLICT (role_key) DO NOTHING;

ALTER TABLE public.portal_credentials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS portal_credentials_portal_manage ON public.portal_credentials;
CREATE POLICY portal_credentials_portal_manage ON public.portal_credentials FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);

NOTIFY pgrst, 'reload schema';

COMMIT;
