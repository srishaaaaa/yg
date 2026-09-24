-- ====================================================================
-- Migration 0027: Split Expenses Ledger per branch
--
-- expenses never got a `branch` column when POS1/POS2 were split
-- (migration 0020), so an expense logged from either counter showed up
-- in one combined ledger. Adds branch isolation matching every other
-- table (products, orders, inventory, advance orders, barcodes).
--
-- expense_categories stays global/shared (a taxonomy list like
-- "Rent"/"Salaries", not a financial record) -- only the actual
-- expense entries are branch-scoped.
--
-- Existing rows default to 'pos1' (pre-split expenses predate the
-- branch split and belong to the original counter), same convention
-- used when products/orders were split.
-- ====================================================================

BEGIN;

ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';

DO $$
BEGIN
  ALTER TABLE public.expenses ADD CONSTRAINT expenses_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_expenses_branch ON public.expenses(branch, expense_date DESC);

DROP FUNCTION IF EXISTS public.get_expense_summary_metrics(DATE);

CREATE OR REPLACE FUNCTION public.get_expense_summary_metrics(
  p_current_date DATE DEFAULT CURRENT_DATE,
  p_branch TEXT DEFAULT 'pos1'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today NUMERIC(12,2) := 0;
  v_this_week NUMERIC(12,2) := 0;
  v_this_month NUMERIC(12,2) := 0;
  v_this_year NUMERIC(12,2) := 0;
  v_total_all_time NUMERIC(12,2) := 0;
  v_week_start DATE := date_trunc('week', p_current_date)::DATE;
  v_month_start DATE := date_trunc('month', p_current_date)::DATE;
  v_year_start DATE := date_trunc('year', p_current_date)::DATE;
  v_branch TEXT := CASE WHEN p_branch = 'pos2' THEN 'pos2' ELSE 'pos1' END;
BEGIN
  SELECT
    COALESCE(SUM(CASE WHEN expense_date = p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN expense_date >= v_week_start AND expense_date <= p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN expense_date >= v_month_start AND expense_date <= p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN expense_date >= v_year_start AND expense_date <= p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(amount), 0)
  INTO
    v_today, v_this_week, v_this_month, v_this_year, v_total_all_time
  FROM public.expenses
  WHERE branch = v_branch;

  RETURN jsonb_build_object(
    'today', v_today,
    'this_week', v_this_week,
    'this_month', v_this_month,
    'this_year', v_this_year,
    'total_all_time', v_total_all_time
  );
END;
$$;

NOTIFY pgrst, 'reload schema';

COMMIT;
