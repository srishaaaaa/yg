-- ====================================================================
-- Migration 0021: Starter catalog for POS 1 (Jute & Wedding Bags) and
-- POS 2 (Clothing), demonstrating the branch-isolated catalogs added in
-- migration 0020. Safe to re-run: every insert is guarded so it never
-- duplicates a category/product that already exists for that branch.
-- Requires migration 0020 (branch columns) to already be applied.
-- ====================================================================

BEGIN;

-- 1. Categories -----------------------------------------------------------

INSERT INTO public.categories (name_en, name_ta, branch, sort_order, is_active)
SELECT v.name_en, v.name_ta, v.branch, v.sort_order, TRUE
FROM (VALUES
  ('Jute Bags',     '', 'pos1', 1),
  ('Wedding Bags',  '', 'pos1', 2),
  ('Wedding Cards', '', 'pos1', 3),
  ('Dresses',       '', 'pos2', 1),
  ('Ethnic Wear',   '', 'pos2', 2),
  ('Kids Wear',     '', 'pos2', 3)
) AS v(name_en, name_ta, branch, sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM public.categories c
  WHERE c.branch = v.branch AND LOWER(BTRIM(c.name_en)) = LOWER(BTRIM(v.name_en))
);

-- 2. Products ---------------------------------------------------------------
-- unit_type 'unit' / unit_label 'piece' — simple non-variant starter items.
-- Prices are placeholders; edit them freely from Inventory once seeded.

INSERT INTO public.products (
  name, category, category_id, branch, price, purchase_price, mrp,
  unit_type, unit_label, unit, base_quantity,
  stock_quantity, stock, low_stock_alert, is_active, sort_order
)
SELECT
  v.name, v.category,
  (SELECT id FROM public.categories WHERE branch = v.branch AND LOWER(BTRIM(name_en)) = LOWER(BTRIM(v.category))),
  v.branch, v.price, v.purchase_price, v.mrp,
  'unit', 'piece', 'piece', 1,
  v.stock, v.stock, 5, TRUE, v.sort_order
FROM (VALUES
  -- POS 1 · Jute & Wedding Bags / Wedding Cards -----------------------
  ('Plain Jute Shopping Bag',          'Jute Bags',     'pos1', 150::numeric,  80::numeric, 180::numeric, 40::numeric, 1),
  ('Printed Jute Tote Bag',            'Jute Bags',     'pos1', 220::numeric, 120::numeric, 260::numeric, 30::numeric, 2),
  ('Floral Jute Tote Bag',             'Jute Bags',     'pos1', 250::numeric, 140::numeric, 300::numeric, 30::numeric, 3),
  ('Designer Jute Bag with Handle',    'Jute Bags',     'pos1', 320::numeric, 180::numeric, 380::numeric, 20::numeric, 4),
  ('Bridal Wedding Return Gift Bag',   'Wedding Bags',  'pos1', 280::numeric, 150::numeric, 340::numeric, 25::numeric, 1),
  ('Embroidered Wedding Favor Bag',    'Wedding Bags',  'pos1', 350::numeric, 190::numeric, 420::numeric, 20::numeric, 2),
  ('Silk Wedding Potli Bag',           'Wedding Bags',  'pos1', 180::numeric, 100::numeric, 220::numeric, 35::numeric, 3),
  ('Traditional Wedding Invitation Card', 'Wedding Cards', 'pos1', 25::numeric, 12::numeric,  30::numeric, 200::numeric, 1),
  ('Floral Wedding Card with Envelope',   'Wedding Cards', 'pos1', 35::numeric, 18::numeric,  42::numeric, 150::numeric, 2),
  ('Premium Laser-Cut Wedding Card',      'Wedding Cards', 'pos1', 65::numeric, 35::numeric,  75::numeric, 100::numeric, 3),

  -- POS 2 · Dresses / Ethnic Wear / Kids Wear -------------------------
  ('Floral Print Cotton Dress',        'Dresses',       'pos2', 799::numeric,  450::numeric,  999::numeric, 30::numeric, 1),
  ('A-Line Party Dress',               'Dresses',       'pos2', 1199::numeric, 700::numeric, 1499::numeric, 20::numeric, 2),
  ('Casual Maxi Dress',                'Dresses',       'pos2', 899::numeric,  520::numeric, 1099::numeric, 25::numeric, 3),
  ('Cotton Anarkali Kurti',            'Ethnic Wear',   'pos2', 699::numeric,  400::numeric,  899::numeric, 30::numeric, 1),
  ('Printed Cotton Saree',             'Ethnic Wear',   'pos2', 1299::numeric, 750::numeric, 1599::numeric, 15::numeric, 2),
  ('Chiffon Party Saree',              'Ethnic Wear',   'pos2', 1599::numeric, 950::numeric, 1999::numeric, 10::numeric, 3),
  ('Kids Cotton Frock',                'Kids Wear',     'pos2', 449::numeric,  250::numeric,  549::numeric, 40::numeric, 1),
  ('Boys Casual Shirt',                'Kids Wear',     'pos2', 399::numeric,  220::numeric,  499::numeric, 40::numeric, 2)
) AS v(name, category, branch, price, purchase_price, mrp, stock, sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM public.products p
  WHERE p.branch = v.branch AND LOWER(BTRIM(p.name)) = LOWER(BTRIM(v.name))
);

COMMIT;
