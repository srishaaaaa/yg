-- ====================================================================
-- Migration 0023: Per-branch Store Settings + Staff Attendance
--
-- 1. store_settings becomes 2 rows (one per branch) instead of a single
--    global row, with extra self-service profile fields (business type,
--    Instagram, logo, accent colour).
-- 2. New staff_members + attendance_records tables: staff pick their name
--    and punch in/out from the POS side; admin sees/overrides it per branch.
-- ====================================================================

BEGIN;

-- 1. Store settings: unlock a 2nd row and add profile fields --------------

ALTER TABLE public.store_settings DROP CONSTRAINT IF EXISTS store_settings_id_check;
ALTER TABLE public.store_settings ADD CONSTRAINT store_settings_id_check CHECK (id IN (1, 2));

ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS business_type TEXT NOT NULL DEFAULT '';
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS instagram_id TEXT NOT NULL DEFAULT '';
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS theme_color TEXT NOT NULL DEFAULT '#8B1A1A';

DO $$
BEGIN
  ALTER TABLE public.store_settings ADD CONSTRAINT store_settings_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS store_settings_branch_unique ON public.store_settings(branch);

UPDATE public.store_settings SET branch = 'pos1', theme_color = '#8B1A1A' WHERE id = 1;

INSERT INTO public.store_settings (id, branch, name, owner_name, phone, email, address, business_type, theme_color, gst_enabled)
VALUES (
  2, 'pos2', 'YG ENTERPRISES', 'M. Gurumoorthy',
  '+91 98844 10700, +91 97878 08090', 'ygenterprises2000@gmail.com',
  '#189, N.S.C. Bose Road, (Opp. Bus Depot, Hotel Sankar Cafe Building), Chennai - 600 001',
  '', '#B8860B', FALSE
)
ON CONFLICT (id) DO NOTHING;

-- 2. Staff members & attendance ------------------------------------------

CREATE TABLE IF NOT EXISTS public.staff_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch TEXT NOT NULL CHECK (branch IN ('pos1', 'pos2')),
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'staff',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS staff_members_branch_idx ON public.staff_members(branch, is_active);

CREATE TABLE IF NOT EXISTS public.attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_member_id UUID NOT NULL REFERENCES public.staff_members(id) ON DELETE CASCADE,
  branch TEXT NOT NULL CHECK (branch IN ('pos1', 'pos2')),
  attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
  clock_in TIMESTAMPTZ,
  clock_out TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'absent', 'half_day', 'leave')),
  note TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (staff_member_id, attendance_date)
);

CREATE INDEX IF NOT EXISTS attendance_records_branch_date_idx ON public.attendance_records(branch, attendance_date DESC);

ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS staff_members_portal_manage ON public.staff_members;
CREATE POLICY staff_members_portal_manage ON public.staff_members FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS attendance_records_portal_manage ON public.attendance_records;
CREATE POLICY attendance_records_portal_manage ON public.attendance_records FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);

-- Punch in/out RPC: upserts today's row for that staff member. Punching
-- "in" only ever sets clock_in the first time (repeat taps don't overwrite
-- an existing clock-in); punching "out" always stamps the latest time.
CREATE OR REPLACE FUNCTION public.punch_attendance(
  p_staff_member_id UUID,
  p_action TEXT
)
RETURNS public.attendance_records
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch TEXT;
  v_row public.attendance_records;
BEGIN
  SELECT branch INTO v_branch FROM public.staff_members WHERE id = p_staff_member_id AND is_active = TRUE;
  IF v_branch IS NULL THEN
    RAISE EXCEPTION 'Staff member not found';
  END IF;

  IF p_action NOT IN ('in', 'out') THEN
    RAISE EXCEPTION 'Invalid punch action';
  END IF;

  INSERT INTO public.attendance_records (staff_member_id, branch, attendance_date, clock_in, clock_out, status)
  VALUES (
    p_staff_member_id, v_branch, CURRENT_DATE,
    CASE WHEN p_action = 'in' THEN NOW() ELSE NULL END,
    CASE WHEN p_action = 'out' THEN NOW() ELSE NULL END,
    'present'
  )
  ON CONFLICT (staff_member_id, attendance_date) DO UPDATE SET
    clock_in = CASE
      WHEN p_action = 'in' AND public.attendance_records.clock_in IS NULL THEN NOW()
      ELSE public.attendance_records.clock_in
    END,
    clock_out = CASE WHEN p_action = 'out' THEN NOW() ELSE public.attendance_records.clock_out END,
    status = 'present',
    updated_at = NOW()
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.punch_attendance(UUID, TEXT) TO anon, authenticated;

COMMIT;
