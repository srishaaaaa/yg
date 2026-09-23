-- ====================================================================
-- Migration 0024: Replace POS 2's starter catalog (clothing, seeded by
-- migration 0022) with a fireworks & crackers catalog matching POS 2's
-- real business. POS 1 already matches its real business (jute/wedding
-- bags, wedding cards) from migration 0022 and is untouched here.
--
-- Scope: every DELETE/SELECT below is filtered to branch = 'pos2', so
-- POS 1's catalog and both branches' `orders` / `order_items` history
-- are never touched. Idempotent: safe to re-run (product/category
-- inserts are guarded, business_type updates are plain overwrites).
-- ====================================================================

BEGIN;

-- 1. Clear POS 2's old clothing catalog only (respecting FK delete order:
-- barcode_registry -> RESTRICT on product_id/variant_id, so it must go
-- first; product_variants and inventory_movements reference products
-- with CASCADE / SET NULL respectively).
DELETE FROM public.barcode_registry WHERE branch = 'pos2';
DELETE FROM public.product_variants WHERE branch = 'pos2';
DELETE FROM public.products WHERE branch = 'pos2';
DELETE FROM public.categories WHERE branch = 'pos2';

-- 2. Seed POS 2's fireworks & crackers categories --------------------------

INSERT INTO public.categories (name_en, name_ta, branch, sort_order, is_active)
SELECT v.name_en, v.name_ta, v.branch, v.sort_order, TRUE
FROM (VALUES
  ('Sparklers',               '', 'pos2', 1),
  ('Flower Pots & Chakras',   '', 'pos2', 2),
  ('Sound & Aerial Crackers', '', 'pos2', 3),
  ('Gift Boxes',              '', 'pos2', 4)
) AS v(name_en, name_ta, branch, sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM public.categories c
  WHERE c.branch = v.branch AND LOWER(BTRIM(c.name_en)) = LOWER(BTRIM(v.name_en))
);

-- 3. Seed POS 2's fireworks & crackers products -----------------------------
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
  v.stock, v.stock, 10, TRUE, v.sort_order
FROM (VALUES
  ('7cm Electric Sparklers (Box of 10)',  'Sparklers',               'pos2',   40::numeric,   22::numeric,   45::numeric, 100::numeric, 1),
  ('10cm Colour Sparklers (Box of 10)',   'Sparklers',               'pos2',   60::numeric,   35::numeric,   68::numeric,  80::numeric, 2),
  ('30cm Sparklers (Box of 5)',           'Sparklers',               'pos2',  120::numeric,   70::numeric,  135::numeric,  60::numeric, 3),
  ('Small Flower Pot (Box of 10)',        'Flower Pots & Chakras',   'pos2',  150::numeric,   90::numeric,  170::numeric,  50::numeric, 1),
  ('Deluxe Flower Pot (Box of 5)',        'Flower Pots & Chakras',   'pos2',  250::numeric,  150::numeric,  280::numeric,  40::numeric, 2),
  ('Ground Chakkar (Pack of 10)',         'Flower Pots & Chakras',   'pos2',   90::numeric,   50::numeric,  100::numeric,  60::numeric, 3),
  ('Lakshmi Sound Crackers (Box of 10)',  'Sound & Aerial Crackers', 'pos2',   90::numeric,   50::numeric,  100::numeric,  70::numeric, 1),
  ('2000 Wala Garland Cracker',           'Sound & Aerial Crackers', 'pos2',  450::numeric,  280::numeric,  500::numeric,  25::numeric, 2),
  ('7 Shot Aerial Fountain',              'Sound & Aerial Crackers', 'pos2',  350::numeric,  210::numeric,  390::numeric,  30::numeric, 3),
  ('Skyshot Rocket (Pack of 5)',          'Sound & Aerial Crackers', 'pos2',  300::numeric,  180::numeric,  330::numeric,  35::numeric, 4),
  ('Family Combo Gift Box',               'Gift Boxes',              'pos2', 1500::numeric,  950::numeric, 1650::numeric,  15::numeric, 1),
  ('Deluxe Assortment Gift Box',          'Gift Boxes',              'pos2', 2500::numeric, 1600::numeric, 2750::numeric,  10::numeric, 2)
) AS v(name, category, branch, price, purchase_price, mrp, stock, sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM public.products p
  WHERE p.branch = v.branch AND LOWER(BTRIM(p.name)) = LOWER(BTRIM(v.name))
);

-- 4. Record each branch's actual business line in Store Settings
-- (Store Settings > Shop Profile > Business Type).
UPDATE public.store_settings SET business_type = 'Wedding Cards, Bags & Jute Bag Manufacturing', updated_at = NOW() WHERE branch = 'pos1';
UPDATE public.store_settings SET business_type = 'Fireworks & Crackers', updated_at = NOW() WHERE branch = 'pos2';

COMMIT;
