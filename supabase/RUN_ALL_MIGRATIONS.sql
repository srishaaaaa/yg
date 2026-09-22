-- ====================================================================
-- COMBINED MIGRATION: run this single file in the Supabase SQL Editor
-- Contains the ENTIRE migration history for this project, in filename
-- order, from the base schema through the POS1/POS2 branch split,
-- CHAJI data cleanup, starter catalog seed, and staff attendance.
--
-- Use this if your Supabase project is EMPTY (no `products`/`orders`
-- tables yet) — running only the later branch-split files will fail
-- with "relation ... does not exist" otherwise, since they only ALTER
-- tables that the base schema (section 1) creates.
--
-- Each original file keeps its own BEGIN/COMMIT block, so this still
-- runs as N sequential transactions, exactly as if you'd pasted every
-- file in supabase/migrations/ one by one in order. Safe to re-run in
-- full from the top at any point (every statement is idempotent via
-- IF NOT EXISTS / IF EXISTS / ON CONFLICT / DROP-before-CREATE guards).
-- ====================================================================

-- ============================================================
-- SECTION 1 / 23 — 20260716_0001_purple_boutique_schema.sql
-- ============================================================

-- YG Enterprises billing schema.
-- Safe to run against a fresh project or the existing YG Enterprises project.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_code TEXT UNIQUE,
  name TEXT NOT NULL DEFAULT '',
  mobile TEXT NOT NULL DEFAULT '',
  email TEXT,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('admin', 'customer')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE SEQUENCE IF NOT EXISTS public.customer_code_seq START WITH 1;

CREATE TABLE IF NOT EXISTS public.categories (
  id BIGSERIAL PRIMARY KEY,
  name_en TEXT NOT NULL UNIQUE,
  name_ta TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.products (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  name_ta TEXT NOT NULL DEFAULT '',
  tamil_name TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT '',
  category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  remedy TEXT[] NOT NULL DEFAULT '{}',
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  offer_price NUMERIC(12,2),
  purchase_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  mrp NUMERIC(12,2) NOT NULL DEFAULT 0,
  gst_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  unit_type TEXT NOT NULL DEFAULT 'unit' CHECK (unit_type IN ('unit', 'weight', 'volume', 'bundle')),
  unit_label TEXT NOT NULL DEFAULT 'piece',
  unit TEXT NOT NULL DEFAULT 'piece',
  base_quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
  stock_quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
  opening_stock NUMERIC(12,3) NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  stock_unit TEXT NOT NULL DEFAULT 'piece',
  low_stock_alert NUMERIC(12,3) NOT NULL DEFAULT 5,
  allow_decimal_quantity BOOLEAN NOT NULL DEFAULT FALSE,
  predefined_options JSONB NOT NULL DEFAULT '[]'::JSONB,
  description TEXT NOT NULL DEFAULT '',
  description_ta TEXT NOT NULL DEFAULT '',
  benefits TEXT NOT NULL DEFAULT '',
  benefits_ta TEXT NOT NULL DEFAULT '',
  image TEXT,
  image_url TEXT,
  sku TEXT,
  barcode TEXT,
  brand TEXT,
  supplier TEXT,
  size TEXT,
  color TEXT,
  rating NUMERIC(3,1) NOT NULL DEFAULT 5,
  has_variants BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS products_category_name_unique
  ON public.products (category_id, LOWER(BTRIM(name)))
  WHERE is_active = true;

CREATE TABLE IF NOT EXISTS public.product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id BIGINT NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  variant_name TEXT NOT NULL,
  size_label TEXT,
  weight_value NUMERIC(12,3),
  weight_unit TEXT,
  sku TEXT,
  barcode TEXT,
  purchase_price NUMERIC(12,2),
  mrp NUMERIC(12,2),
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  stock NUMERIC(12,3) NOT NULL DEFAULT 0,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  image_url TEXT,
  group_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS product_variants_product_name_unique
  ON public.product_variants (product_id, LOWER(BTRIM(variant_name)))
  WHERE is_active = true;

CREATE TABLE IF NOT EXISTS public.coupons (
  id BIGSERIAL PRIMARY KEY,
  code TEXT NOT NULL,
  percentage NUMERIC(5,2) NOT NULL CHECK (percentage > 0 AND percentage <= 100),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  expiry_date TIMESTAMPTZ,
  usage_limit INTEGER CHECK (usage_limit IS NULL OR usage_limit > 0),
  usage_count INTEGER NOT NULL DEFAULT 0 CHECK (usage_count >= 0),
  min_order_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS coupons_code_upper_unique ON public.coupons (UPPER(BTRIM(code)));

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no TEXT NOT NULL UNIQUE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL DEFAULT 'Customer',
  phone TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  items JSONB NOT NULL DEFAULT '[]'::JSONB,
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
  shipping NUMERIC(12,2) NOT NULL DEFAULT 0,
  total NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  order_mode TEXT NOT NULL DEFAULT 'offline',
  order_type TEXT NOT NULL DEFAULT 'pos_sale',
  delivery_charge NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  manual_discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  manual_discount_type TEXT NOT NULL DEFAULT 'flat',
  manual_discount_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  coupon_code TEXT,
  coupon_percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
  total_gst NUMERIC(12,2) NOT NULL DEFAULT 0,
  gst_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  gst_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  payment_mode TEXT NOT NULL DEFAULT 'cash',
  split_details JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id BIGINT REFERENCES public.products(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL DEFAULT 'Product',
  name TEXT NOT NULL DEFAULT 'Product',
  product_tamil_name TEXT,
  tamil_name TEXT,
  quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'piece',
  unit_type TEXT NOT NULL DEFAULT 'unit',
  base_quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
  base_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  line_total NUMERIC(12,2) NOT NULL DEFAULT 0,
  image_url TEXT,
  is_manual BOOLEAN NOT NULL DEFAULT FALSE,
  discount NUMERIC(12,2) NOT NULL DEFAULT 0,
  gst_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  gst_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.invoice_counter (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  counter BIGINT NOT NULL DEFAULT 0,
  year INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM NOW())::INTEGER,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.invoice_counter (id, counter, year)
VALUES (1, 0, EXTRACT(YEAR FROM NOW())::INTEGER)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.store_settings (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  name TEXT NOT NULL DEFAULT 'YG Enterprises',
  owner_name TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '+60 11-3312 7107',
  email TEXT NOT NULL DEFAULT 'mypurpleboutique05@gmail.com',
  address TEXT NOT NULL DEFAULT 'FR-02-05A TAMARIND SUITE, Persiaran Multimedia, CYBER 10, 63000 Cyberjaya, Selangor',
  gst_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.store_settings (id, name, phone, email, address)
VALUES (
  1,
  'YG Enterprises',
  '+60 11-3312 7107',
  'mypurpleboutique05@gmail.com',
  'FR-02-05A TAMARIND SUITE, Persiaran Multimedia, CYBER 10, 63000 Cyberjaya, Selangor'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  phone = EXCLUDED.phone,
  email = EXCLUDED.email,
  address = EXCLUDED.address,
  updated_at = NOW();

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin';
$$;

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := CASE WHEN COALESCE(NEW.raw_user_meta_data ->> 'role', '') = 'admin' THEN 'admin' ELSE 'customer' END;
BEGIN
  INSERT INTO public.profiles (id, customer_code, name, mobile, email, role)
  VALUES (
    NEW.id,
    'CUST-' || LPAD(nextval('public.customer_code_seq')::TEXT, 5, '0'),
    COALESCE(NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'name'), ''), split_part(COALESCE(NEW.email, ''), '@', 1), 'Customer'),
    COALESCE(NEW.raw_user_meta_data ->> 'mobile', ''),
    NEW.email,
    v_role
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    mobile = EXCLUDED.mobile,
    email = EXCLUDED.email,
    updated_at = NOW();

  UPDATE auth.users
  SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::JSONB) || jsonb_build_object('role', v_role)
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.sync_product_category_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.category_id IS NOT NULL THEN
    SELECT name_en INTO NEW.category FROM public.categories WHERE id = NEW.category_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_product_category_name_trigger ON public.products;
CREATE TRIGGER sync_product_category_name_trigger
BEFORE INSERT OR UPDATE OF category_id ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_category_name();

CREATE OR REPLACE FUNCTION public.sync_category_name_to_products()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.name_en IS DISTINCT FROM OLD.name_en THEN
    UPDATE public.products SET category = NEW.name_en, updated_at = NOW() WHERE category_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_category_name_to_products_trigger ON public.categories;
CREATE TRIGGER sync_category_name_to_products_trigger
AFTER UPDATE OF name_en ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.sync_category_name_to_products();

CREATE OR REPLACE FUNCTION public.ensure_one_default_variant()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.is_default THEN
    UPDATE public.product_variants
    SET is_default = FALSE, updated_at = NOW()
    WHERE product_id = NEW.product_id AND id <> NEW.id AND is_default;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ensure_one_default_variant_trigger ON public.product_variants;
CREATE TRIGGER ensure_one_default_variant_trigger
AFTER INSERT OR UPDATE OF is_default ON public.product_variants
FOR EACH ROW EXECUTE FUNCTION public.ensure_one_default_variant();

CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year INTEGER := EXTRACT(YEAR FROM NOW())::INTEGER;
  v_counter BIGINT;
  v_existing_max BIGINT;
BEGIN
  SELECT COALESCE(MAX(SUBSTRING(invoice_no FROM '^PB-' || v_year || '-([0-9]+)$')::BIGINT), 0)
  INTO v_existing_max
  FROM public.orders
  WHERE invoice_no ~ ('^PB-' || v_year || '-[0-9]+$');

  INSERT INTO public.invoice_counter (id, counter, year)
  VALUES (1, 1, v_year)
  ON CONFLICT (id) DO UPDATE SET
    counter = CASE
      WHEN public.invoice_counter.year = v_year
        THEN GREATEST(public.invoice_counter.counter, v_existing_max) + 1
      ELSE 1
    END,
    year = v_year,
    updated_at = NOW()
  RETURNING counter INTO v_counter;

  RETURN 'PB-' || v_year || '-' || LPAD(v_counter::TEXT, 6, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public.create_order_with_stock(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'pending',
  p_order_mode TEXT DEFAULT 'offline',
  p_order_type TEXT DEFAULT 'pos_sale',
  p_delivery_charge NUMERIC DEFAULT 0,
  p_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type TEXT DEFAULT 'flat',
  p_manual_discount_value NUMERIC DEFAULT 0,
  p_coupon_code TEXT DEFAULT NULL,
  p_coupon_percentage NUMERIC DEFAULT 0,
  p_total_gst NUMERIC DEFAULT 0,
  p_gst_enabled BOOLEAN DEFAULT FALSE,
  p_payment_method TEXT DEFAULT 'cash',
  p_split_details JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC(12,2) := 0;
  v_total NUMERIC(12,2);
  v_item JSONB;
  v_product_id BIGINT;
  v_variant_id UUID;
  v_attempt INTEGER;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_subtotal := v_subtotal + COALESCE((v_item ->> 'line_total')::NUMERIC, 0);
  END LOOP;

  v_total := GREATEST(
    0,
    v_subtotal + COALESCE(p_total_gst, 0) + COALESCE(p_delivery_charge, 0) + COALESCE(p_shipping, 0)
      - COALESCE(p_discount_amount, 0) - COALESCE(p_manual_discount_amount, 0)
  );

  FOR v_attempt IN 1..5 LOOP
    v_invoice_no := public.get_next_invoice_no();
    BEGIN
      INSERT INTO public.orders (
        invoice_no, user_id, customer_name, phone, address, items, subtotal, shipping, total,
        status, order_mode, order_type, delivery_charge, discount_amount, manual_discount_amount,
        manual_discount_type, manual_discount_value, coupon_code, coupon_percentage, total_gst,
        gst_amount, gst_enabled, payment_method, payment_mode, split_details
      ) VALUES (
        v_invoice_no, auth.uid(), COALESCE(NULLIF(BTRIM(p_customer_name), ''), 'Customer'),
        COALESCE(BTRIM(p_phone), ''), COALESCE(BTRIM(p_address), ''), p_items, v_subtotal,
        COALESCE(p_shipping, 0), v_total, COALESCE(NULLIF(BTRIM(p_status), ''), 'pending'),
        COALESCE(NULLIF(BTRIM(p_order_mode), ''), 'offline'), COALESCE(NULLIF(BTRIM(p_order_type), ''), 'pos_sale'),
        COALESCE(p_delivery_charge, 0), COALESCE(p_discount_amount, 0), COALESCE(p_manual_discount_amount, 0),
        COALESCE(NULLIF(BTRIM(p_manual_discount_type), ''), 'flat'), COALESCE(p_manual_discount_value, 0),
        NULLIF(BTRIM(COALESCE(p_coupon_code, '')), ''), COALESCE(p_coupon_percentage, 0),
        COALESCE(p_total_gst, 0), COALESCE(p_total_gst, 0), COALESCE(p_gst_enabled, FALSE),
        COALESCE(NULLIF(BTRIM(p_payment_method), ''), 'cash'), COALESCE(NULLIF(BTRIM(p_payment_method), ''), 'cash'),
        COALESCE(p_split_details, '{}'::JSONB)
      ) RETURNING id INTO v_order_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      IF v_attempt = 5 THEN RAISE; END IF;
    END;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_product_id := NULLIF(COALESCE(v_item ->> 'product_id', v_item ->> 'id'), '')::BIGINT;
    v_variant_id := NULLIF(v_item ->> 'variant_id', '')::UUID;

    INSERT INTO public.order_items (
      order_id, product_id, variant_id, product_name, name, product_tamil_name, tamil_name,
      quantity, unit, unit_type, base_quantity, base_price, line_total, image_url, is_manual,
      discount, gst_amount, gst_rate
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      COALESCE(NULLIF(v_item ->> 'name', ''), 'Product'), COALESCE(NULLIF(v_item ->> 'name', ''), 'Product'),
      NULLIF(v_item ->> 'tamil_name', ''), NULLIF(v_item ->> 'tamil_name', ''),
      COALESCE((v_item ->> 'quantity')::NUMERIC, 0), COALESCE(NULLIF(v_item ->> 'unit', ''), 'piece'),
      COALESCE(NULLIF(v_item ->> 'unit_type', ''), 'unit'), COALESCE((v_item ->> 'base_quantity')::NUMERIC, 1),
      COALESCE((v_item ->> 'base_price')::NUMERIC, 0), COALESCE((v_item ->> 'line_total')::NUMERIC, 0),
      NULLIF(v_item ->> 'image_url', ''), COALESCE(v_item ->> 'source' = 'manual', FALSE),
      COALESCE((v_item ->> 'discount')::NUMERIC, 0), COALESCE((v_item ->> 'gst_amount')::NUMERIC, 0),
      COALESCE((v_item ->> 'gst_rate')::NUMERIC, 0)
    );

    IF v_product_id IS NOT NULL THEN
      UPDATE public.products
      SET stock_quantity = GREATEST(stock_quantity - COALESCE((v_item ->> 'quantity')::NUMERIC, 0), 0),
          stock = GREATEST(FLOOR(stock_quantity - COALESCE((v_item ->> 'quantity')::NUMERIC, 0)), 0)::INTEGER,
          updated_at = NOW()
      WHERE id = v_product_id;
    END IF;

    IF v_variant_id IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock = GREATEST(stock - COALESCE((v_item ->> 'quantity')::NUMERIC, 0), 0), updated_at = NOW()
      WHERE id = v_variant_id;
    END IF;
  END LOOP;

  IF NULLIF(BTRIM(COALESCE(p_coupon_code, '')), '') IS NOT NULL THEN
    UPDATE public.coupons
    SET usage_count = usage_count + 1, updated_at = NOW()
    WHERE UPPER(BTRIM(code)) = UPPER(BTRIM(p_coupon_code))
      AND is_active
      AND (usage_limit IS NULL OR usage_count < usage_limit);
  END IF;

  RETURN jsonb_build_object('orderId', v_order_id, 'invoiceNo', v_invoice_no, 'createdAt', NOW());
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_invoice_by_number(p_invoice_no TEXT)
RETURNS SETOF public.orders
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM public.orders WHERE invoice_no = NULLIF(BTRIM(p_invoice_no), '') LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_public_invoice_by_number(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_invoice_by_number(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC,
  TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, JSONB
) TO anon, authenticated;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_portal_manage ON public.profiles;
CREATE POLICY profiles_portal_manage ON public.profiles FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS categories_portal_manage ON public.categories;
CREATE POLICY categories_portal_manage ON public.categories FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS products_portal_manage ON public.products;
CREATE POLICY products_portal_manage ON public.products FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS product_variants_portal_manage ON public.product_variants;
CREATE POLICY product_variants_portal_manage ON public.product_variants FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS coupons_portal_manage ON public.coupons;
CREATE POLICY coupons_portal_manage ON public.coupons FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS orders_portal_manage ON public.orders;
CREATE POLICY orders_portal_manage ON public.orders FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS order_items_portal_manage ON public.order_items;
CREATE POLICY order_items_portal_manage ON public.order_items FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);
DROP POLICY IF EXISTS store_settings_portal_manage ON public.store_settings;
CREATE POLICY store_settings_portal_manage ON public.store_settings FOR ALL TO anon, authenticated USING (TRUE) WITH CHECK (TRUE);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('invoices', 'invoices', TRUE, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = TRUE, file_size_limit = 10485760, allowed_mime_types = ARRAY['application/pdf'];

DROP POLICY IF EXISTS invoices_public_read ON storage.objects;
CREATE POLICY invoices_public_read ON storage.objects FOR SELECT TO public USING (bucket_id = 'invoices');
DROP POLICY IF EXISTS invoices_portal_upload ON storage.objects;
CREATE POLICY invoices_portal_upload ON storage.objects FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'invoices');
DROP POLICY IF EXISTS invoices_portal_update ON storage.objects;
CREATE POLICY invoices_portal_update ON storage.objects FOR UPDATE TO anon, authenticated USING (bucket_id = 'invoices') WITH CHECK (bucket_id = 'invoices');

CREATE INDEX IF NOT EXISTS products_category_id_idx ON public.products(category_id);
CREATE INDEX IF NOT EXISTS products_active_sort_idx ON public.products(is_active, sort_order);
CREATE INDEX IF NOT EXISTS variants_product_id_idx ON public.product_variants(product_id);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS orders_phone_idx ON public.orders(phone);
CREATE INDEX IF NOT EXISTS order_items_order_id_idx ON public.order_items(order_id);

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

-- ============================================================
-- SECTION 2 / 23 — 20260716_0002_purple_boutique_catalog.sql
-- ============================================================

-- YG Enterprises initial catalog. Existing matching products are preserved.

INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
VALUES
  ('Tailoring', '', TRUE, 1),
  ('Jewellery & Accessories', '', TRUE, 2),
  ('Posstore', '', TRUE, 3)
ON CONFLICT (name_en) DO UPDATE SET
  is_active = TRUE,
  sort_order = EXCLUDED.sort_order,
  updated_at = NOW();

WITH catalog(category_name, product_name, sort_order) AS (
  VALUES
    ('Tailoring', 'Saree Blouse', 101),
    ('Tailoring', 'Saree Blouse + Cup', 102),
    ('Tailoring', 'Readymade Saree', 103),
    ('Tailoring', 'Punjabi Suit', 104),
    ('Tailoring', 'Punjabi Suit + Salwar', 105),
    ('Tailoring', 'Baju Kurung', 106),
    ('Tailoring', 'Baju Kebaya', 107),
    ('Tailoring', 'Baju Melaya', 108),
    ('Tailoring', 'Lehelga', 109),
    ('Tailoring', 'Alterations', 110),
    ('Tailoring', 'Pavadai Sattai', 111),
    ('Tailoring', 'Designs', 112),
    ('Tailoring', 'Add-ons', 113),
    ('Jewellery & Accessories', 'Earrings', 201),
    ('Jewellery & Accessories', 'Bridal Jewellery Rent', 202),
    ('Jewellery & Accessories', 'Choker Set', 203),
    ('Jewellery & Accessories', 'Anklet', 204),
    ('Jewellery & Accessories', 'Add-ons', 205),
    ('Posstore', 'Claim Parcel', 301),
    ('Posstore', 'Perfume', 302),
    ('Posstore', 'Add-ons', 303)
), resolved AS (
  SELECT c.id AS category_id, c.name_en AS category_name, catalog.product_name, catalog.sort_order
  FROM catalog
  JOIN public.categories c ON LOWER(c.name_en) = LOWER(catalog.category_name)
)
INSERT INTO public.products (
  name, category, category_id, price, purchase_price, mrp, unit_type, unit_label,
  unit, base_quantity, stock_quantity, opening_stock, stock, stock_unit,
  allow_decimal_quantity, predefined_options, description, is_active, sort_order
)
SELECT
  resolved.product_name,
  resolved.category_name,
  resolved.category_id,
  0,
  0,
  0,
  'unit',
  'piece',
  'piece',
  1,
  999,
  999,
  999,
  'piece',
  FALSE,
  '[]'::JSONB,
  resolved.product_name || ' service or product',
  TRUE,
  resolved.sort_order
FROM resolved
WHERE NOT EXISTS (
  SELECT 1
  FROM public.products p
  WHERE p.category_id = resolved.category_id
    AND LOWER(BTRIM(p.name)) = LOWER(BTRIM(resolved.product_name))
);

UPDATE public.products p
SET is_active = TRUE,
    category = c.name_en,
    updated_at = NOW()
FROM public.categories c
WHERE p.category_id = c.id
  AND c.name_en IN ('Tailoring', 'Jewellery & Accessories', 'Posstore');

WITH catalog(category_name, product_name, sort_order) AS (
  VALUES
    ('Tailoring', 'Saree Blouse', 101),
    ('Tailoring', 'Saree Blouse + Cup', 102),
    ('Tailoring', 'Readymade Saree', 103),
    ('Tailoring', 'Punjabi Suit', 104),
    ('Tailoring', 'Punjabi Suit + Salwar', 105),
    ('Tailoring', 'Baju Kurung', 106),
    ('Tailoring', 'Baju Kebaya', 107),
    ('Tailoring', 'Baju Melaya', 108),
    ('Tailoring', 'Lehelga', 109),
    ('Tailoring', 'Alterations', 110),
    ('Tailoring', 'Pavadai Sattai', 111),
    ('Tailoring', 'Designs', 112),
    ('Tailoring', 'Add-ons', 113),
    ('Jewellery & Accessories', 'Earrings', 201),
    ('Jewellery & Accessories', 'Bridal Jewellery Rent', 202),
    ('Jewellery & Accessories', 'Choker Set', 203),
    ('Jewellery & Accessories', 'Anklet', 204),
    ('Jewellery & Accessories', 'Add-ons', 205),
    ('Posstore', 'Claim Parcel', 301),
    ('Posstore', 'Perfume', 302),
    ('Posstore', 'Add-ons', 303)
)
UPDATE public.products p
SET name = catalog.product_name,
    sort_order = catalog.sort_order,
    updated_at = NOW()
FROM catalog
JOIN public.categories c ON LOWER(c.name_en) = LOWER(catalog.category_name)
WHERE p.category_id = c.id
  AND LOWER(BTRIM(p.name)) = LOWER(BTRIM(catalog.product_name));

-- ============================================================
-- SECTION 3 / 23 — 20260716_0003_order_rpc_compatibility.sql
-- ============================================================

-- Align the live legacy billing schema with the current YG Enterprises RPC payload.
-- Idempotent: safe for both upgraded and freshly migrated projects.

BEGIN;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS gst_enabled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS split_details JSONB NOT NULL DEFAULT '{}'::JSONB;

-- Keep one order-item shape that works with both the legacy and current schemas.
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS variant_name TEXT;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS unit_price NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'catalogue';
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS note TEXT;

CREATE SEQUENCE IF NOT EXISTS public.invoice_number_seq;

-- Prevent collisions when a sequence is introduced after invoices already exist.
DO $$
DECLARE
  v_max_suffix BIGINT;
  v_sequence_value BIGINT;
BEGIN
  SELECT COALESCE(MAX((regexp_match(invoice_no, '-([0-9]+)$'))[1]::BIGINT), 0)
  INTO v_max_suffix
  FROM public.orders
  WHERE invoice_no ~ '-[0-9]+$';

  SELECT last_value INTO v_sequence_value FROM public.invoice_number_seq;
  PERFORM setval(
    'public.invoice_number_seq',
    GREATEST(v_max_suffix, v_sequence_value, 1),
    TRUE
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
VOLATILE
AS $$
  SELECT 'PB-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' ||
         LPAD(nextval('public.invoice_number_seq')::TEXT, 6, '0');
$$;

CREATE OR REPLACE FUNCTION public.create_order_with_stock(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'pending',
  p_order_mode TEXT DEFAULT 'offline',
  p_order_type TEXT DEFAULT 'pos_sale',
  p_delivery_charge NUMERIC DEFAULT 0,
  p_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type TEXT DEFAULT 'flat',
  p_manual_discount_value NUMERIC DEFAULT 0,
  p_coupon_code TEXT DEFAULT NULL,
  p_coupon_percentage NUMERIC DEFAULT 0,
  p_total_gst NUMERIC DEFAULT 0,
  p_gst_enabled BOOLEAN DEFAULT FALSE,
  p_payment_method TEXT DEFAULT 'cash',
  p_split_details JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC(12,2) := 0;
  v_total NUMERIC(12,2);
  v_item JSONB;
  v_quantity NUMERIC(12,3);
  v_price NUMERIC(12,2);
  v_line_total NUMERIC(12,2);
  v_source TEXT;
  v_attempt INTEGER;
  v_uses_typed_item_ids BOOLEAN;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_quantity := GREATEST(COALESCE(NULLIF(v_item ->> 'quantity', '')::NUMERIC, 0), 0);
    v_price := GREATEST(COALESCE(NULLIF(v_item ->> 'base_price', '')::NUMERIC, 0), 0);
    v_line_total := GREATEST(
      COALESCE(NULLIF(v_item ->> 'line_total', '')::NUMERIC, v_quantity * v_price),
      0
    );

    IF v_quantity <= 0 THEN
      RAISE EXCEPTION 'Item quantity must be greater than zero';
    END IF;

    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  v_total := GREATEST(
    ROUND(
      v_subtotal + GREATEST(COALESCE(p_shipping, 0), 0)
        + GREATEST(COALESCE(p_delivery_charge, 0), 0)
        + GREATEST(COALESCE(p_total_gst, 0), 0)
        - GREATEST(COALESCE(p_discount_amount, 0), 0)
        - GREATEST(COALESCE(p_manual_discount_amount, 0), 0),
      2
    ),
    0
  );

  SELECT data_type = 'bigint'
  INTO v_uses_typed_item_ids
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'order_items' AND column_name = 'product_id';

  FOR v_attempt IN 1..5 LOOP
    v_invoice_no := public.get_next_invoice_no();
    v_order_id := gen_random_uuid();

    BEGIN
      INSERT INTO public.orders (
        id, invoice_no, user_id, customer_name, phone, address, items, subtotal, shipping, total,
        status, order_mode, order_type, delivery_charge, discount_amount, manual_discount_amount,
        manual_discount_type, manual_discount_value, coupon_code, coupon_percentage, total_gst,
        gst_amount, gst_enabled, payment_method, payment_mode, split_details, created_at, updated_at
      ) VALUES (
        v_order_id, v_invoice_no, auth.uid(),
        COALESCE(NULLIF(BTRIM(p_customer_name), ''), 'Walk-in Customer'),
        COALESCE(BTRIM(p_phone), ''), COALESCE(NULLIF(BTRIM(p_address), ''), 'POS Counter'),
        p_items, v_subtotal, GREATEST(COALESCE(p_shipping, 0), 0), v_total,
        COALESCE(NULLIF(BTRIM(p_status), ''), 'pending'),
        COALESCE(NULLIF(BTRIM(p_order_mode), ''), 'offline'),
        COALESCE(NULLIF(BTRIM(p_order_type), ''), 'pos_sale'),
        GREATEST(COALESCE(p_delivery_charge, 0), 0),
        GREATEST(COALESCE(p_discount_amount, 0), 0),
        GREATEST(COALESCE(p_manual_discount_amount, 0), 0),
        COALESCE(NULLIF(BTRIM(p_manual_discount_type), ''), 'flat'),
        GREATEST(COALESCE(p_manual_discount_value, 0), 0),
        NULLIF(BTRIM(COALESCE(p_coupon_code, '')), ''),
        GREATEST(COALESCE(p_coupon_percentage, 0), 0),
        GREATEST(COALESCE(p_total_gst, 0), 0), GREATEST(COALESCE(p_total_gst, 0), 0),
        COALESCE(p_gst_enabled, FALSE),
        COALESCE(NULLIF(BTRIM(p_payment_method), ''), 'cash'),
        COALESCE(NULLIF(BTRIM(p_payment_method), ''), 'cash'),
        COALESCE(p_split_details, '{}'::JSONB), NOW(), NOW()
      );
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      IF v_attempt = 5 THEN
        RAISE;
      END IF;
    END;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_quantity := GREATEST(COALESCE(NULLIF(v_item ->> 'quantity', '')::NUMERIC, 0), 0);
    v_price := GREATEST(COALESCE(NULLIF(v_item ->> 'base_price', '')::NUMERIC, 0), 0);
    v_line_total := GREATEST(
      COALESCE(NULLIF(v_item ->> 'line_total', '')::NUMERIC, v_quantity * v_price),
      0
    );
    v_source := COALESCE(NULLIF(v_item ->> 'source', ''), 'catalogue');

    IF v_uses_typed_item_ids THEN
      INSERT INTO public.order_items (
        order_id, product_id, variant_id, product_name, tamil_name, variant_name,
        quantity, unit, unit_price, line_total, is_manual, source, note
      ) VALUES (
        v_order_id, NULLIF(COALESCE(v_item ->> 'product_id', v_item ->> 'id'), '')::BIGINT,
        NULLIF(v_item ->> 'variant_id', '')::UUID, COALESCE(NULLIF(v_item ->> 'name', ''), 'Product'),
        NULLIF(v_item ->> 'tamil_name', ''), NULLIF(v_item ->> 'variant_name', ''),
        v_quantity, COALESCE(NULLIF(v_item ->> 'unit', ''), 'piece'), v_price, v_line_total,
        v_source = 'manual', v_source, NULLIF(v_item ->> 'note', '')
      );
    ELSE
      INSERT INTO public.order_items (
        order_id, product_id, variant_id, product_name, tamil_name, variant_name,
        quantity, unit, unit_price, line_total, is_manual, source, note
      ) VALUES (
        v_order_id, NULLIF(COALESCE(v_item ->> 'product_id', v_item ->> 'id'), ''),
        NULLIF(v_item ->> 'variant_id', ''), COALESCE(NULLIF(v_item ->> 'name', ''), 'Product'),
        NULLIF(v_item ->> 'tamil_name', ''), NULLIF(v_item ->> 'variant_name', ''),
        v_quantity, COALESCE(NULLIF(v_item ->> 'unit', ''), 'piece'), v_price, v_line_total,
        v_source = 'manual', v_source, NULLIF(v_item ->> 'note', '')
      );
    END IF;

    IF COALESCE(v_item ->> 'product_id', v_item ->> 'id', '') ~ '^[0-9]+$' THEN
      UPDATE public.products
      SET stock_quantity = GREATEST(stock_quantity - v_quantity, 0),
          stock = GREATEST(FLOOR(stock_quantity - v_quantity), 0)::INTEGER,
          updated_at = NOW()
      WHERE id::TEXT = COALESCE(v_item ->> 'product_id', v_item ->> 'id');
    END IF;

    IF NULLIF(v_item ->> 'variant_id', '') IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock = GREATEST(stock - v_quantity, 0), updated_at = NOW()
      WHERE id::TEXT = v_item ->> 'variant_id';
    END IF;
  END LOOP;

  IF NULLIF(BTRIM(COALESCE(p_coupon_code, '')), '') IS NOT NULL THEN
    UPDATE public.coupons
    SET usage_count = usage_count + 1
    WHERE UPPER(BTRIM(code)) = UPPER(BTRIM(p_coupon_code))
      AND is_active
      AND (usage_limit IS NULL OR usage_count < usage_limit);
  END IF;

  RETURN jsonb_build_object(
    'orderId', v_order_id,
    'invoiceNo', v_invoice_no,
    'createdAt', NOW()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC,
  TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, JSONB
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC,
  TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, JSONB
) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ============================================================
-- SECTION 4 / 23 — 20260719_0004_advance_orders.sql
-- ============================================================

begin;

create sequence if not exists public.deposit_number_seq start 1;

alter table public.order_items add column if not exists category text;

create table if not exists public.advance_orders (
  id uuid primary key default gen_random_uuid(),
  deposit_id text not null unique,
  customer_name text not null,
  phone text not null,
  address text not null default '',
  product_name text not null,
  products jsonb not null default '[]'::jsonb,
  category text not null default '',
  description text not null default '',
  total_amount numeric(12,2) not null check (total_amount > 0),
  deposit_amount numeric(12,2) not null check (deposit_amount > 0),
  remaining_balance numeric(12,2) generated always as (total_amount - deposit_amount) stored,
  expected_delivery_date date not null,
  status text not null default 'pending_deposit' check (status in ('pending_deposit','ready_for_delivery','waiting_final_payment','completed','cancelled')),
  remarks text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_by_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  completed_order_id uuid unique references public.orders(id),
  invoice_number text unique,
  final_payment_method text,
  constraint advance_deposit_less_than_total check (deposit_amount < total_amount)
);

alter table public.advance_orders add column if not exists products jsonb not null default '[]'::jsonb;

create table if not exists public.advance_order_timeline (
  id bigint generated always as identity primary key,
  advance_order_id uuid not null references public.advance_orders(id) on delete cascade,
  event_type text not null,
  label text not null,
  remarks text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.advance_order_payments (
  id uuid primary key default gen_random_uuid(),
  advance_order_id uuid not null references public.advance_orders(id) on delete cascade,
  payment_type text not null check (payment_type in ('deposit','remaining')),
  amount numeric(12,2) not null check (amount >= 0),
  payment_method text not null check (payment_method in ('cash','upi','card')),
  remarks text not null default '',
  received_by uuid references auth.users(id) on delete set null,
  received_at timestamptz not null default now(),
  unique (advance_order_id, payment_type)
);

create index if not exists advance_orders_created_idx on public.advance_orders(created_at desc);
create index if not exists advance_orders_status_idx on public.advance_orders(status);
create index if not exists advance_orders_delivery_idx on public.advance_orders(expected_delivery_date);
create index if not exists advance_order_timeline_order_idx on public.advance_order_timeline(advance_order_id, created_at);
create index if not exists advance_order_payments_order_idx on public.advance_order_payments(advance_order_id, received_at);

drop function if exists public.create_advance_order(text,text,text,text,text,text,numeric,numeric,date,text,text,text);
create or replace function public.create_advance_order(
  p_customer_name text, p_phone text, p_address text, p_product_name text,
  p_category text, p_description text, p_total_amount numeric, p_deposit_amount numeric,
  p_expected_delivery_date date, p_remarks text, p_payment_method text, p_created_by_name text,
  p_products jsonb default '[]'::jsonb
)
returns public.advance_orders
language plpgsql security definer set search_path = public
as $$
declare v_order public.advance_orders; v_now timestamptz := now(); v_deposit_id text;
begin
  if trim(coalesce(p_customer_name,'')) = '' then raise exception 'Customer name is required'; end if;
  if trim(coalesce(p_phone,'')) = '' then raise exception 'Phone number is required'; end if;
  if trim(coalesce(p_product_name,'')) = '' then raise exception 'Product name is required'; end if;
  if coalesce(p_total_amount,0) <= 0 then raise exception 'Total amount must be greater than zero'; end if;
  if coalesce(p_deposit_amount,0) <= 0 or p_deposit_amount >= p_total_amount then raise exception 'Deposit must be greater than zero and less than the total amount'; end if;
  if lower(coalesce(p_payment_method,'')) not in ('cash','upi','card') then raise exception 'Select a valid deposit payment method'; end if;
  v_deposit_id := 'DEP-' || to_char(v_now at time zone 'Asia/Kolkata','YYYYMMDD') || '-' || lpad(nextval('public.deposit_number_seq')::text,4,'0');
  insert into public.advance_orders(deposit_id,customer_name,phone,address,product_name,products,category,description,total_amount,deposit_amount,expected_delivery_date,remarks,created_by,created_by_name,created_at,updated_at)
  values(v_deposit_id,trim(p_customer_name),trim(p_phone),trim(coalesce(p_address,'')),trim(p_product_name),case when jsonb_typeof(coalesce(p_products,'[]'::jsonb))='array' then coalesce(p_products,'[]'::jsonb) else '[]'::jsonb end,trim(coalesce(p_category,'')),trim(coalesce(p_description,'')),round(p_total_amount,2),round(p_deposit_amount,2),p_expected_delivery_date,trim(coalesce(p_remarks,'')),auth.uid(),trim(coalesce(p_created_by_name,'')),v_now,v_now)
  returning * into v_order;
  insert into public.advance_order_payments(advance_order_id,payment_type,amount,payment_method,remarks,received_by,received_at)
  values(v_order.id,'deposit',v_order.deposit_amount,lower(p_payment_method),coalesce(p_remarks,''),auth.uid(),v_now);
  insert into public.advance_order_timeline(advance_order_id,event_type,label,created_by,created_at) values
    (v_order.id,'created','Created',auth.uid(),v_now),
    (v_order.id,'deposit_received','Deposit Received',auth.uid(),v_now);
  return v_order;
end;
$$;

drop function if exists public.update_advance_order_status(uuid, text, text);
create or replace function public.update_advance_order_status(p_order_id uuid, p_status text, p_remarks text default '')
returns public.advance_orders
language plpgsql security definer set search_path = public
as $$
declare v_order public.advance_orders; v_label text;
begin
  if p_status not in ('pending_deposit','ready_for_delivery','waiting_final_payment','cancelled') then raise exception 'Invalid status transition'; end if;
  select * into v_order from public.advance_orders where id=p_order_id for update;
  if not found then raise exception 'Advance order not found'; end if;
  if v_order.status='completed' then raise exception 'A completed order cannot be changed'; end if;
  v_label := case p_status when 'ready_for_delivery' then 'Tailoring Completed' when 'waiting_final_payment' then 'Customer Contacted' when 'cancelled' then 'Cancelled' else 'Pending Deposit' end;
  update public.advance_orders set status=p_status,remarks=case when trim(coalesce(p_remarks,''))='' then remarks else p_remarks end,updated_at=now() where id=p_order_id returning * into v_order;
  insert into public.advance_order_timeline(advance_order_id,event_type,label,remarks,created_by) values(p_order_id,p_status,v_label,coalesce(p_remarks,''),auth.uid());
  return v_order;
end;
$$;

create or replace function public.add_advance_order_event(p_order_id uuid, p_event_type text, p_label text, p_remarks text default '')
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not exists(select 1 from public.advance_orders where id=p_order_id) then raise exception 'Advance order not found'; end if;
  insert into public.advance_order_timeline(advance_order_id,event_type,label,remarks,created_by) values(p_order_id,p_event_type,p_label,coalesce(p_remarks,''),auth.uid());
end;
$$;

create or replace function public.complete_advance_order(p_order_id uuid, p_payment_method text, p_remarks text default '')
returns table(order_id uuid, invoice_no text, completed_at timestamptz)
language plpgsql security definer set search_path = public
as $$
declare v_advance public.advance_orders; v_order_id uuid := gen_random_uuid(); v_invoice text; v_now timestamptz := now(); v_items jsonb; v_item jsonb;
begin
  if lower(coalesce(p_payment_method,'')) not in ('cash','upi','card') then raise exception 'Select a valid payment method'; end if;
  select * into v_advance from public.advance_orders where id=p_order_id for update;
  if not found then raise exception 'Advance order not found'; end if;
  if v_advance.status='cancelled' then raise exception 'A cancelled order cannot be completed'; end if;
  if v_advance.completed_order_id is not null or v_advance.invoice_number is not null then raise exception 'Invoice already generated for this order'; end if;
  v_invoice := 'PB-' || to_char(v_now at time zone 'Asia/Kolkata','YYYYMMDD') || '-' || lpad(nextval('public.invoice_number_seq')::text,6,'0');
  v_items := case when jsonb_typeof(v_advance.products)='array' and jsonb_array_length(v_advance.products)>0 then v_advance.products else jsonb_build_array(jsonb_build_object('name',v_advance.product_name,'category',v_advance.category,'description',v_advance.description,'quantity',1,'base_price',v_advance.total_amount,'line_total',v_advance.total_amount,'unit','piece','unit_type','unit','source','advance_order')) end;
  insert into public.orders(id,invoice_no,customer_name,phone,address,user_id,items,subtotal,total,status,order_mode,order_type,shipping,delivery_charge,discount_amount,manual_discount_amount,payment_mode,payment_method,created_at,updated_at)
  values(v_order_id,v_invoice,v_advance.customer_name,v_advance.phone,v_advance.address,auth.uid(),v_items,v_advance.total_amount,v_advance.total_amount,'completed','offline','advance_order',0,0,0,0,lower(p_payment_method),lower(p_payment_method),v_now,v_now);
  for v_item in select value from jsonb_array_elements(v_items) loop
    insert into public.order_items(order_id,product_name,category,quantity,unit,unit_price,line_total,is_manual,source,note)
    values(v_order_id,coalesce(nullif(v_item->>'name',''),'Product'),coalesce(nullif(v_item->>'category',''),v_advance.category),greatest(coalesce(nullif(v_item->>'quantity','')::numeric,1),0),coalesce(nullif(v_item->>'unit',''),'piece'),greatest(coalesce(nullif(v_item->>'base_price','')::numeric,0),0),greatest(coalesce(nullif(v_item->>'line_total','')::numeric,0),0),false,'advance_order',coalesce(nullif(v_item->>'note',''),v_advance.description));
  end loop;
  insert into public.advance_order_payments(advance_order_id,payment_type,amount,payment_method,remarks,received_by,received_at)
  values(p_order_id,'remaining',v_advance.remaining_balance,lower(p_payment_method),coalesce(p_remarks,''),auth.uid(),v_now);
  update public.advance_orders set status='completed',completed_at=v_now,completed_order_id=v_order_id,invoice_number=v_invoice,final_payment_method=lower(p_payment_method),remarks=case when trim(coalesce(p_remarks,''))='' then remarks else p_remarks end,updated_at=v_now where id=p_order_id;
  insert into public.advance_order_timeline(advance_order_id,event_type,label,remarks,created_by,created_at) values
    (p_order_id,'remaining_payment_received','Remaining Payment Received',coalesce(p_remarks,''),auth.uid(),v_now),
    (p_order_id,'invoice_generated','Invoice Generated',v_invoice,auth.uid(),v_now);
  return query select v_order_id,v_invoice,v_now;
end;
$$;

alter table public.advance_orders enable row level security;
alter table public.advance_order_timeline enable row level security;
alter table public.advance_order_payments enable row level security;

drop policy if exists "Allow all for advance orders" on public.advance_orders;
create policy "Allow all for advance orders" on public.advance_orders for all using (true) with check (true);

drop policy if exists "Allow all for advance timeline" on public.advance_order_timeline;
create policy "Allow all for advance timeline" on public.advance_order_timeline for all using (true) with check (true);

drop policy if exists "Allow all for advance payments" on public.advance_order_payments;
create policy "Allow all for advance payments" on public.advance_order_payments for all using (true) with check (true);

grant usage, select on sequence public.deposit_number_seq to public, anon, authenticated;
grant usage, select on sequence public.invoice_number_seq to public, anon, authenticated;

grant select, insert, update, delete on public.advance_orders to public, anon, authenticated;
grant select, insert, update, delete on public.advance_order_timeline to public, anon, authenticated;
grant select, insert, update, delete on public.advance_order_payments to public, anon, authenticated;

grant execute on function public.create_advance_order(text,text,text,text,text,text,numeric,numeric,date,text,text,text,jsonb) to public, anon, authenticated;
grant execute on function public.update_advance_order_status(uuid,text,text) to public, anon, authenticated;
grant execute on function public.add_advance_order_event(uuid,text,text,text) to public, anon, authenticated;
grant execute on function public.complete_advance_order(uuid,text,text) to public, anon, authenticated;

notify pgrst, 'reload schema';
commit;

-- ============================================================
-- SECTION 5 / 23 — 20260722_0005_eight_digit_invoice_numbers.sql
-- ============================================================

-- Migration: 8-digit Invoice Number Generation
-- Ensures invoice numbers are strictly 8 digits in total (e.g., 10000001, 10000002...)

CREATE SEQUENCE IF NOT EXISTS public.invoice_number_seq START WITH 10000001;

CREATE OR REPLACE FUNCTION public.get_next_invoice_no()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
VOLATILE
AS $$
  SELECT LPAD(nextval('public.invoice_number_seq')::TEXT, 8, '0');
$$;

-- ============================================================
-- SECTION 6 / 23 — 20260724_0006_fix_complete_advance_order.sql
-- ============================================================

-- Migration: Fix complete_advance_order RPC
-- The previous version referenced columns (unit_price, source, note) that do
-- not exist in the order_items table. This patch corrects the insert to use
-- the actual column names: base_price, line_total, is_manual.

CREATE OR REPLACE FUNCTION public.complete_advance_order(
  p_order_id uuid,
  p_payment_method text,
  p_remarks text DEFAULT ''
)
RETURNS TABLE(order_id uuid, invoice_no text, completed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_advance        public.advance_orders;
  v_order_id       uuid := gen_random_uuid();
  v_invoice        text;
  v_now            timestamptz := now();
  v_items          jsonb;
  v_item           jsonb;
BEGIN
  -- Validate payment method
  IF lower(coalesce(p_payment_method, '')) NOT IN ('cash', 'upi', 'card') THEN
    RAISE EXCEPTION 'Select a valid payment method';
  END IF;

  -- Lock and fetch the advance order
  SELECT * INTO v_advance FROM public.advance_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Advance order not found';
  END IF;
  IF v_advance.status = 'cancelled' THEN
    RAISE EXCEPTION 'A cancelled order cannot be completed';
  END IF;
  IF v_advance.completed_order_id IS NOT NULL OR v_advance.invoice_number IS NOT NULL THEN
    RAISE EXCEPTION 'Invoice already generated for this order';
  END IF;

  -- Generate invoice number using the existing 8-digit sequence
  v_invoice := LPAD(nextval('public.invoice_number_seq')::TEXT, 8, '0');

  -- Build items JSONB — prefer products array, fall back to single product
  v_items := CASE
    WHEN jsonb_typeof(v_advance.products) = 'array' AND jsonb_array_length(v_advance.products) > 0
      THEN v_advance.products
    ELSE jsonb_build_array(
      jsonb_build_object(
        'name',        v_advance.product_name,
        'category',    v_advance.category,
        'description', v_advance.description,
        'quantity',    1,
        'base_price',  v_advance.total_amount,
        'line_total',  v_advance.total_amount,
        'unit',        'piece',
        'unit_type',   'unit',
        'source',      'advance_order'
      )
    )
  END;

  -- Create the final sale order
  INSERT INTO public.orders (
    id, invoice_no, customer_name, phone, address, user_id,
    items, subtotal, total, status, order_mode, order_type,
    shipping, delivery_charge, discount_amount, manual_discount_amount,
    payment_mode, payment_method, created_at, updated_at
  ) VALUES (
    v_order_id, v_invoice,
    v_advance.customer_name, v_advance.phone, v_advance.address, auth.uid(),
    v_items, v_advance.total_amount, v_advance.total_amount,
    'completed', 'offline', 'advance_order',
    0, 0, 0, 0,
    lower(p_payment_method), lower(p_payment_method),
    v_now, v_now
  );

  -- Insert order_items using the CORRECT column names from the schema
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    INSERT INTO public.order_items (
      order_id, product_name, name, quantity, unit, unit_type,
      base_price, line_total, is_manual
    ) VALUES (
      v_order_id,
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      greatest(coalesce((v_item->>'quantity')::numeric, 1), 0),
      coalesce(nullif(v_item->>'unit', ''), 'piece'),
      coalesce(nullif(v_item->>'unit_type', ''), 'unit'),
      greatest(coalesce((v_item->>'base_price')::numeric, 0), 0),
      greatest(coalesce((v_item->>'line_total')::numeric, 0), 0),
      false
    );
  END LOOP;

  -- Record the final payment received
  INSERT INTO public.advance_order_payments (
    advance_order_id, payment_type, amount, payment_method, remarks, received_by, received_at
  ) VALUES (
    p_order_id, 'remaining', v_advance.remaining_balance,
    lower(p_payment_method), coalesce(p_remarks, ''), auth.uid(), v_now
  );

  -- Mark advance order as completed
  UPDATE public.advance_orders SET
    status               = 'completed',
    completed_at         = v_now,
    completed_order_id   = v_order_id,
    invoice_number       = v_invoice,
    final_payment_method = lower(p_payment_method),
    remarks              = CASE WHEN trim(coalesce(p_remarks, '')) = '' THEN remarks ELSE p_remarks END,
    updated_at           = v_now
  WHERE id = p_order_id;

  -- Timeline events
  INSERT INTO public.advance_order_timeline (
    advance_order_id, event_type, label, remarks, created_by, created_at
  ) VALUES
    (p_order_id, 'remaining_payment_received', 'Remaining Payment Received', coalesce(p_remarks, ''), auth.uid(), v_now),
    (p_order_id, 'invoice_generated',          'Invoice Generated',          v_invoice,               auth.uid(), v_now);

  RETURN QUERY SELECT v_order_id, v_invoice, v_now;
END;
$$;

-- Re-grant execute permission
GRANT EXECUTE ON FUNCTION public.complete_advance_order(uuid, text, text)
  TO public, anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- SECTION 7 / 23 — 20260724_0008_fix_public_invoice_rpc.sql
-- ============================================================

-- Migration: Fix missing get_public_invoice_by_number RPC
-- Re-creates the function and forces a schema cache reload to resolve 404 errors on the /invoice page

CREATE OR REPLACE FUNCTION public.get_public_invoice_by_number(p_invoice_no TEXT)
RETURNS SETOF public.orders
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM public.orders WHERE invoice_no = NULLIF(BTRIM(p_invoice_no), '') LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_public_invoice_by_number(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_invoice_by_number(TEXT) TO anon, authenticated;

-- Force PostgREST to reload the schema cache
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- SECTION 8 / 23 — 20260724_0009_create_invoices_bucket.sql
-- ============================================================

-- Migration: Create invoices storage bucket
-- Creates the 'invoices' bucket and sets up public read access and upload policies

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('invoices', 'invoices', TRUE, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = TRUE, file_size_limit = 10485760, allowed_mime_types = ARRAY['application/pdf'];

DROP POLICY IF EXISTS invoices_public_read ON storage.objects;
CREATE POLICY invoices_public_read ON storage.objects FOR SELECT TO public USING (bucket_id = 'invoices');

DROP POLICY IF EXISTS invoices_portal_upload ON storage.objects;
CREATE POLICY invoices_portal_upload ON storage.objects FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'invoices');

DROP POLICY IF EXISTS invoices_portal_update ON storage.objects;
CREATE POLICY invoices_portal_update ON storage.objects FOR UPDATE TO anon, authenticated USING (bucket_id = 'invoices') WITH CHECK (bucket_id = 'invoices');

-- ============================================================
-- SECTION 9 / 23 — 20260726_0007_update_complete_advance_order_discount.sql
-- ============================================================

-- Migration: Update complete_advance_order to handle final amount, discounts, and coupons
-- This creates a new version of the RPC (v2) which is called from the frontend.

CREATE OR REPLACE FUNCTION public.complete_advance_order_v2(
  p_order_id uuid,
  p_payment_method text,
  p_final_amount numeric,
  p_coupon_code text DEFAULT NULL,
  p_coupon_percentage numeric DEFAULT 0,
  p_manual_discount numeric DEFAULT 0,
  p_remarks text DEFAULT ''
)
RETURNS TABLE(order_id uuid, invoice_no text, completed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_advance        public.advance_orders;
  v_order_id       uuid := gen_random_uuid();
  v_invoice        text;
  v_now            timestamptz := now();
  v_items          jsonb;
  v_item           jsonb;
  v_total_discount numeric := 0;
BEGIN
  -- Validate payment method
  IF lower(coalesce(p_payment_method, '')) NOT IN ('cash', 'upi', 'card') THEN
    RAISE EXCEPTION 'Select a valid payment method';
  END IF;

  -- Lock and fetch the advance order
  SELECT * INTO v_advance FROM public.advance_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Advance order not found';
  END IF;
  IF v_advance.status = 'cancelled' THEN
    RAISE EXCEPTION 'A cancelled order cannot be completed';
  END IF;
  IF v_advance.completed_order_id IS NOT NULL OR v_advance.invoice_number IS NOT NULL THEN
    RAISE EXCEPTION 'Invoice already generated for this order';
  END IF;

  -- Calculate the total discount from manual discount and coupon
  v_total_discount := p_manual_discount + (v_advance.remaining_balance - p_manual_discount - p_final_amount);
  IF v_total_discount < 0 THEN
    v_total_discount := 0;
  END IF;

  -- Generate invoice number using the existing 8-digit sequence
  v_invoice := LPAD(nextval('public.invoice_number_seq')::TEXT, 8, '0');

  -- Build items JSONB - prefer products array, fall back to single product
  v_items := CASE
    WHEN jsonb_typeof(v_advance.products) = 'array' AND jsonb_array_length(v_advance.products) > 0
      THEN v_advance.products
    ELSE jsonb_build_array(
      jsonb_build_object(
        'name',        v_advance.product_name,
        'category',    v_advance.category,
        'description', v_advance.description,
        'quantity',    1,
        'base_price',  v_advance.total_amount,
        'line_total',  v_advance.total_amount,
        'unit',        'piece',
        'unit_type',   'unit',
        'source',      'advance_order'
      )
    )
  END;

  -- Create the final sale order, storing the discount information
  INSERT INTO public.orders (
    id, invoice_no, customer_name, phone, address, user_id,
    items, subtotal, total, status, order_mode, order_type,
    shipping, delivery_charge, discount_amount, manual_discount_amount,
    coupon_code, coupon_percentage, manual_discount_type, manual_discount_value,
    payment_mode, payment_method, created_at, updated_at
  ) VALUES (
    v_order_id, v_invoice,
    v_advance.customer_name, v_advance.phone, v_advance.address, auth.uid(),
    v_items, v_advance.total_amount, greatest(0, v_advance.total_amount - v_total_discount),
    'completed', 'offline', 'advance_order',
    0, 0, v_total_discount, p_manual_discount,
    p_coupon_code, p_coupon_percentage, 'flat', p_manual_discount,
    lower(p_payment_method), lower(p_payment_method),
    v_now, v_now
  );

  -- Insert order_items using the CORRECT column names from the schema
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    INSERT INTO public.order_items (
      order_id, product_name, name, quantity, unit, unit_type,
      base_price, line_total, is_manual
    ) VALUES (
      v_order_id,
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      greatest(coalesce((v_item->>'quantity')::numeric, 1), 0),
      coalesce(nullif(v_item->>'unit', ''), 'piece'),
      coalesce(nullif(v_item->>'unit_type', ''), 'unit'),
      greatest(coalesce((v_item->>'base_price')::numeric, 0), 0),
      greatest(coalesce((v_item->>'line_total')::numeric, 0), 0),
      false
    );
  END LOOP;

  -- Record the final payment received
  INSERT INTO public.advance_order_payments (
    advance_order_id, payment_type, amount, payment_method, remarks, received_by, received_at
  ) VALUES (
    p_order_id, 'remaining', p_final_amount,
    lower(p_payment_method), coalesce(p_remarks, ''), auth.uid(), v_now
  );

  -- Mark advance order as completed. Note that remaining_balance is GENERATED ALWAYS AS (total_amount - deposit_amount)
  -- so we do not update remaining_balance directly, but the UI considers it "paid".
  UPDATE public.advance_orders SET
    status               = 'completed',
    completed_at         = v_now,
    completed_order_id   = v_order_id,
    invoice_number       = v_invoice,
    final_payment_method = lower(p_payment_method),
    remarks              = CASE WHEN trim(coalesce(p_remarks, '')) = '' THEN remarks ELSE p_remarks END,
    updated_at           = v_now
  WHERE id = p_order_id;

  -- Timeline events
  INSERT INTO public.advance_order_timeline (
    advance_order_id, event_type, label, remarks, created_by, created_at
  ) VALUES
    (p_order_id, 'remaining_payment_received', 'Remaining Payment Received', coalesce(p_remarks, ''), auth.uid(), v_now),
    (p_order_id, 'invoice_generated',          'Invoice Generated',          v_invoice,               auth.uid(), v_now);

  RETURN QUERY SELECT v_order_id, v_invoice, v_now;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.complete_advance_order_v2(uuid, text, numeric, text, numeric, numeric, text)
  TO public, anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- SECTION 10 / 23 — 20260728_0010_final_audit_fixes.sql
-- ============================================================

-- ============================================================
-- Migration 0010: Final audit fixes
-- Date: 2026-07-28
-- Purpose: Fix all remaining production issues found in audit
-- ============================================================

-- 1. Create store_reviews table (used by Home.tsx but never created in any migration)
CREATE TABLE IF NOT EXISTS public.store_reviews (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    text,
  reviewer    text,
  rating      integer CHECK (rating BETWEEN 1 AND 5),
  comment     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
DROP FUNCTION IF EXISTS update_advance_order_status(uuid, text, text);
ALTER TABLE public.store_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can insert reviews" ON public.store_reviews;
CREATE POLICY "Anyone can insert reviews" ON public.store_reviews FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can read reviews" ON public.store_reviews;
CREATE POLICY "Anyone can read reviews"  ON public.store_reviews FOR SELECT USING (true);

-- 2. Make completed_order_id FK in advance_orders ON DELETE SET NULL
--    so that deleting an order from the orders table does not require
--    manually clearing advance_orders.completed_order_id first.
--    (Our frontend now also clears it first, but this is the proper DB-level safety net)
ALTER TABLE public.advance_orders
  DROP CONSTRAINT IF EXISTS advance_orders_completed_order_id_fkey;

ALTER TABLE public.advance_orders
  ADD CONSTRAINT advance_orders_completed_order_id_fkey
  FOREIGN KEY (completed_order_id)
  REFERENCES public.orders(id)
  ON DELETE SET NULL;

-- 3. Ensure invoice_no column in advance_orders stores the INV-prefixed number
--    (already works via complete_advance_order_v2, but add index for faster lookup)
CREATE INDEX IF NOT EXISTS idx_advance_orders_invoice_number ON public.advance_orders(invoice_number);
CREATE INDEX IF NOT EXISTS idx_advance_orders_status ON public.advance_orders(status);
CREATE INDEX IF NOT EXISTS idx_advance_orders_created_at ON public.advance_orders(created_at DESC);

-- 4. Ensure orders table has index on invoice_no for fast public invoice lookups
CREATE INDEX IF NOT EXISTS idx_orders_invoice_no ON public.orders(invoice_no);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);

-- 5. Ensure update_advance_order_status RPC is up to date and handles all statuses
CREATE OR REPLACE FUNCTION public.update_advance_order_status(
  p_order_id uuid,
  p_status   text,
  p_remarks  text DEFAULT ''
)
RETURNS SETOF public.advance_orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.advance_orders;
BEGIN
  SELECT * INTO v_order FROM public.advance_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Advance order % not found', p_order_id;
  END IF;

  UPDATE public.advance_orders SET
    status     = p_status,
    remarks    = CASE WHEN trim(coalesce(p_remarks,'')) = '' THEN remarks ELSE p_remarks END,
    updated_at = now()
  WHERE id = p_order_id;

  INSERT INTO public.advance_order_timeline (advance_order_id, event_type, label, remarks, created_by, created_at)
  VALUES (
    p_order_id,
    p_status,
    CASE p_status
      WHEN 'pending_deposit'      THEN 'Status: Pending Deposit'
      WHEN 'waiting_final_payment' THEN 'Status: Waiting for Final Payment'
      WHEN 'ready_for_delivery'   THEN 'Status: Ready to Collect'
      WHEN 'completed'            THEN 'Order Completed'
      WHEN 'cancelled'            THEN 'Order Cancelled'
      ELSE p_status
    END,
    coalesce(p_remarks, ''),
    auth.uid(),
    now()
  );

  RETURN QUERY SELECT * FROM public.advance_orders WHERE id = p_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_advance_order_status(uuid, text, text) TO authenticated, anon, public;

-- 6. Ensure add_advance_order_event RPC is robust
CREATE OR REPLACE FUNCTION public.add_advance_order_event(
  p_order_id   uuid,
  p_event_type text,
  p_label      text,
  p_remarks    text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.advance_order_timeline (advance_order_id, event_type, label, remarks, created_by, created_at)
  VALUES (p_order_id, p_event_type, p_label, coalesce(p_remarks,''), auth.uid(), now());
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_advance_order_event(uuid, text, text, text) TO authenticated, anon, public;

-- 7. Ensure profiles RLS allows staff to update their own profile (avatar etc)
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- 8. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- SECTION 11 / 23 — 20260808_0011_billing_date_and_order_fields.sql
-- ============================================================

-- ============================================================
-- Migration 0011: Add billing_date and ensure order metadata columns exist
-- Date: 2026-08-08
-- Purpose:
--   1. Add optional billing_date column to orders table so admins
--      can backdate or set a custom billing date/time per sale.
--   2. Ensure remarks and reference_number columns exist (they were
--      added via the dashboard and used in existing client code).
-- ============================================================

BEGIN;

-- Ensure remarks column exists (used by Pos.tsx update call)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS remarks TEXT NOT NULL DEFAULT '';

-- Ensure reference_number column exists (used by Pos.tsx update call)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS reference_number TEXT NOT NULL DEFAULT '';

-- Add optional billing_date column.
-- When NULL the UI falls back to created_at for display.
-- When set, it represents the admin-chosen billing date/time.
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS billing_date TIMESTAMPTZ;

-- Index for fast lookup by billing_date in analytics
CREATE INDEX IF NOT EXISTS idx_orders_billing_date ON public.orders(billing_date);

-- Reload PostgREST schema cache so the new column is immediately accessible
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ============================================================
-- SECTION 12 / 23 — 20260901_0012_inventory_barcode_addon.sql
-- ============================================================

-- ====================================================================
-- Migration 0012: Barcode Management & Inventory Movement Ledger Addon
-- ====================================================================

BEGIN;

-- 1. Sequences for Barcode Generation
CREATE SEQUENCE IF NOT EXISTS public.barcode_product_seq START WITH 10000001;
CREATE SEQUENCE IF NOT EXISTS public.barcode_variant_seq START WITH 10000001;

-- 2. Canonical Barcode Registry
CREATE TABLE IF NOT EXISTS public.barcode_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barcode_value TEXT NOT NULL UNIQUE,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('product', 'variant')),
  product_id BIGINT NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE RESTRICT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by_name TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_barcode_entity_target CHECK (
    (entity_type = 'product' AND variant_id IS NULL) OR
    (entity_type = 'variant' AND variant_id IS NOT NULL)
  )
);

-- 3. Inventory Movement Ledger
CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT REFERENCES public.products(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL,
  barcode_id UUID REFERENCES public.barcode_registry(id) ON DELETE SET NULL,
  movement_type TEXT NOT NULL CHECK (
    movement_type IN ('INITIAL_BARCODE_STOCK', 'RESTOCK', 'SALE', 'RETURN', 'DAMAGE', 'CORRECTION', 'VOID')
  ),
  quantity_delta NUMERIC NOT NULL,
  quantity_before NUMERIC NOT NULL,
  quantity_after NUMERIC NOT NULL,
  unit_cost NUMERIC DEFAULT NULL,
  reference_type TEXT DEFAULT NULL, -- 'order', 'adjustment', 'barcode_receipt'
  reference_id TEXT DEFAULT NULL,   -- order_id or invoice_no
  note TEXT DEFAULT '',
  created_by_name TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Indexes for Rapid POS Lookup & Audit Reports
CREATE INDEX IF NOT EXISTS idx_barcode_registry_val ON public.barcode_registry(barcode_value);
CREATE INDEX IF NOT EXISTS idx_barcode_registry_prod ON public.barcode_registry(product_id);
CREATE INDEX IF NOT EXISTS idx_barcode_registry_var ON public.barcode_registry(variant_id) WHERE variant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inv_movements_prod ON public.inventory_movements(product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_movements_var ON public.inventory_movements(variant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_movements_type ON public.inventory_movements(movement_type, created_at DESC);

-- 5. Enable RLS and Policies
ALTER TABLE public.barcode_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS barcode_registry_all ON public.barcode_registry;
CREATE POLICY barcode_registry_all ON public.barcode_registry FOR ALL USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS inventory_movements_all ON public.inventory_movements;
CREATE POLICY inventory_movements_all ON public.inventory_movements FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 6. Helper Function: Generate Unique Barcode String
CREATE OR REPLACE FUNCTION public.generate_barcode_value(p_entity_type TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_entity_type = 'variant' THEN
    RETURN 'PBV' || LPAD(nextval('public.barcode_variant_seq')::TEXT, 8, '0');
  ELSE
    RETURN 'PBP' || LPAD(nextval('public.barcode_product_seq')::TEXT, 8, '0');
  END IF;
END;
$$;

-- 7. Transactional RPC: Create Barcode & Receive Stock (With Barcode Reuse on Restock)
CREATE OR REPLACE FUNCTION public.create_barcode_and_receive_stock(
  p_product_id BIGINT,
  p_variant_id UUID DEFAULT NULL,
  p_quantity_received NUMERIC DEFAULT 0,
  p_unit_cost NUMERIC DEFAULT NULL,
  p_created_by_name TEXT DEFAULT '',
  p_custom_barcode TEXT DEFAULT NULL,
  p_note TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_entity_type TEXT;
  v_barcode_id UUID;
  v_barcode_value TEXT;
  v_is_new_barcode BOOLEAN := FALSE;
  v_movement_type TEXT;
  v_qty_before NUMERIC := 0;
  v_qty_after NUMERIC := 0;
  v_prod_name TEXT;
  v_var_name TEXT := '';
BEGIN
  IF p_quantity_received < 0 THEN
    RAISE EXCEPTION 'Quantity received cannot be negative';
  END IF;

  -- 1. Check Parent Product Exists
  SELECT name INTO v_prod_name FROM public.products WHERE id = p_product_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product with ID % not found', p_product_id;
  END IF;

  -- 2. Verify Variant Belongs to Product if Variant is Provided
  IF p_variant_id IS NOT NULL THEN
    v_entity_type := 'variant';
    SELECT variant_name, stock INTO v_var_name, v_qty_before
    FROM public.product_variants
    WHERE id = p_variant_id AND product_id = p_product_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant % does not belong to Product %', p_variant_id, p_product_id;
    END IF;
  ELSE
    v_entity_type := 'product';
    SELECT stock_quantity INTO v_qty_before
    FROM public.products
    WHERE id = p_product_id;
  END IF;

  -- 3. Check for Existing Active Barcode in barcode_registry (SKU Identity)
  IF v_entity_type = 'variant' THEN
    SELECT id, barcode_value INTO v_barcode_id, v_barcode_value
    FROM public.barcode_registry
    WHERE variant_id = p_variant_id AND is_active = TRUE
    ORDER BY created_at DESC
    LIMIT 1;
  ELSE
    SELECT id, barcode_value INTO v_barcode_id, v_barcode_value
    FROM public.barcode_registry
    WHERE product_id = p_product_id AND variant_id IS NULL AND is_active = TRUE
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  -- 4. Reuse Existing or Create New Barcode
  IF v_barcode_id IS NOT NULL THEN
    v_is_new_barcode := FALSE;
    v_movement_type := CASE WHEN v_qty_before = 0 THEN 'INITIAL_BARCODE_STOCK' ELSE 'RESTOCK' END;
  ELSE
    v_is_new_barcode := TRUE;
    v_movement_type := 'INITIAL_BARCODE_STOCK';
    v_barcode_value := COALESCE(NULLIF(UPPER(BTRIM(p_custom_barcode)), ''), public.generate_barcode_value(v_entity_type));

    INSERT INTO public.barcode_registry (
      barcode_value, entity_type, product_id, variant_id, is_active, created_by_name
    )
    VALUES (
      v_barcode_value, v_entity_type, p_product_id, p_variant_id, TRUE, COALESCE(p_created_by_name, '')
    )
    RETURNING id INTO v_barcode_id;
  END IF;

  -- 5. Synchronize compatibility column on target table
  IF v_entity_type = 'variant' THEN
    UPDATE public.product_variants
    SET barcode = v_barcode_value, updated_at = NOW()
    WHERE id = p_variant_id;
  ELSE
    UPDATE public.products
    SET barcode = v_barcode_value, updated_at = NOW()
    WHERE id = p_product_id;
  END IF;

  -- 6. Apply Stock Increment & Parent Aggregate Sync
  v_qty_after := v_qty_before + p_quantity_received;

  IF p_quantity_received > 0 THEN
    IF v_entity_type = 'variant' THEN
      UPDATE public.product_variants
      SET stock = v_qty_after, updated_at = NOW()
      WHERE id = p_variant_id;
  
      -- Refresh parent aggregate stock cache
      UPDATE public.products
      SET stock_quantity = (
            SELECT COALESCE(SUM(stock), 0)
            FROM public.product_variants
            WHERE product_id = p_product_id AND is_active = TRUE
          ),
          stock = FLOOR((
            SELECT COALESCE(SUM(stock), 0)
            FROM public.product_variants
            WHERE product_id = p_product_id AND is_active = TRUE
          ))::INTEGER,
          updated_at = NOW()
      WHERE id = p_product_id;
    ELSE
      UPDATE public.products
      SET stock_quantity = v_qty_after,
          stock = FLOOR(v_qty_after)::INTEGER,
          updated_at = NOW()
      WHERE id = p_product_id;
    END IF;
  END IF;

  -- 7. Record Immutable Inventory Movement
  IF p_quantity_received > 0 THEN
    INSERT INTO public.inventory_movements (
      product_id, variant_id, barcode_id, movement_type,
      quantity_delta, quantity_before, quantity_after,
      unit_cost, reference_type, reference_id, note, created_by_name
    )
    VALUES (
      p_product_id, p_variant_id, v_barcode_id, v_movement_type,
      p_quantity_received, v_qty_before, v_qty_after,
      p_unit_cost, 'barcode_receipt', v_barcode_value,
      COALESCE(p_note, ''), COALESCE(p_created_by_name, '')
    );
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'barcode_id', v_barcode_id,
    'barcode_value', v_barcode_value,
    'is_new_barcode', v_is_new_barcode,
    'movement_type', v_movement_type,
    'quantity_before', v_qty_before,
    'quantity_received', p_quantity_received,
    'quantity_after', v_qty_after,
    'product_id', p_product_id,
    'variant_id', p_variant_id,
    'product_name', v_prod_name,
    'variant_name', v_var_name
  );
END;
$$;

-- 8. Transactional RPC: Adjust Stock (Restock, Damage, Correction, Return)
CREATE OR REPLACE FUNCTION public.adjust_inventory_stock(
  p_product_id BIGINT,
  p_variant_id UUID DEFAULT NULL,
  p_new_quantity NUMERIC DEFAULT 0,
  p_reason TEXT DEFAULT 'RESTOCK',
  p_note TEXT DEFAULT '',
  p_created_by_name TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qty_before NUMERIC := 0;
  v_delta NUMERIC := 0;
  v_barcode_id UUID;
BEGIN
  IF p_new_quantity < 0 THEN
    RAISE EXCEPTION 'Stock quantity cannot be negative';
  END IF;

  -- Verify variant if supplied
  IF p_variant_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.product_variants WHERE id = p_variant_id AND product_id = p_product_id) THEN
      RAISE EXCEPTION 'Variant does not belong to specified Product';
    END IF;

    SELECT stock INTO v_qty_before FROM public.product_variants WHERE id = p_variant_id FOR UPDATE;
    SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE variant_id = p_variant_id AND is_active = TRUE LIMIT 1;
    
    v_delta := p_new_quantity - v_qty_before;

    UPDATE public.product_variants
    SET stock = p_new_quantity, updated_at = NOW()
    WHERE id = p_variant_id;

    -- Refresh parent aggregate
    UPDATE public.products
    SET stock_quantity = (SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = p_product_id AND is_active = TRUE),
        stock = FLOOR((SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = p_product_id AND is_active = TRUE))::INTEGER,
        updated_at = NOW()
    WHERE id = p_product_id;
  ELSE
    SELECT stock_quantity INTO v_qty_before FROM public.products WHERE id = p_product_id FOR UPDATE;
    SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE product_id = p_product_id AND variant_id IS NULL AND is_active = TRUE LIMIT 1;

    v_delta := p_new_quantity - v_qty_before;

    UPDATE public.products
    SET stock_quantity = p_new_quantity,
        stock = FLOOR(p_new_quantity)::INTEGER,
        updated_at = NOW()
    WHERE id = p_product_id;
  END IF;

  -- Record Movement
  INSERT INTO public.inventory_movements (
    product_id, variant_id, barcode_id, movement_type,
    quantity_delta, quantity_before, quantity_after,
    reference_type, note, created_by_name
  )
  VALUES (
    p_product_id, p_variant_id, v_barcode_id, p_reason,
    v_delta, v_qty_before, p_new_quantity,
    'adjustment', COALESCE(p_note, ''), COALESCE(p_created_by_name, '')
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'quantity_before', v_qty_before,
    'quantity_after', p_new_quantity,
    'delta', v_delta,
    'reason', p_reason
  );
END;
$$;

-- 9. Transactional RPC: Complete POS Sale with Inventory Pre-Validation & Movement Ledger
CREATE OR REPLACE FUNCTION public.complete_pos_sale_with_inventory(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'completed',
  p_order_mode TEXT DEFAULT 'offline',
  p_order_type TEXT DEFAULT 'pos_sale',
  p_delivery_charge NUMERIC DEFAULT 0,
  p_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type TEXT DEFAULT 'flat',
  p_manual_discount_value NUMERIC DEFAULT 0,
  p_coupon_code TEXT DEFAULT NULL,
  p_coupon_percentage NUMERIC DEFAULT 0,
  p_payment_method TEXT DEFAULT 'cash',
  p_split_details JSONB DEFAULT '{}'::JSONB,
  p_total_gst NUMERIC DEFAULT 0,
  p_gst_enabled BOOLEAN DEFAULT FALSE,
  p_remarks TEXT DEFAULT NULL,
  p_reference_number TEXT DEFAULT NULL,
  p_billing_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC := 0;
  v_total NUMERIC := 0;
  v_item JSONB;
  v_product_id BIGINT;
  v_variant_id UUID;
  v_quantity NUMERIC;
  v_unit_price NUMERIC;
  v_line_total NUMERIC;
  v_product_name TEXT;
  v_name_ta TEXT;
  v_unit TEXT;
  v_unit_type TEXT;
  v_base_quantity NUMERIC;
  v_is_manual BOOLEAN;
  v_discount NUMERIC;
  v_gst_amount NUMERIC;
  v_gst_rate NUMERIC;
  v_image_url TEXT;
  v_variant_name TEXT;
  v_source TEXT;
  v_note TEXT;
  v_category TEXT;
  v_current_stock NUMERIC;
  v_barcode_id UUID;
  v_created_at TIMESTAMPTZ := COALESCE(p_billing_date, NOW());
BEGIN
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order items cannot be empty';
  END IF;

  -- 1. Atomic Pre-Validation of Available Stock for All Items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := NULLIF(v_item ->> 'product_id', '')::BIGINT;
    v_variant_id := NULLIF(v_item ->> 'variant_id', '')::UUID;
    v_quantity := COALESCE((v_item ->> 'quantity')::NUMERIC, 0);
    v_is_manual := COALESCE((v_item ->> 'is_manual')::BOOLEAN, FALSE);
    v_product_name := COALESCE(v_item ->> 'product_name', v_item ->> 'name', 'Product');

    IF NOT v_is_manual AND v_quantity > 0 THEN
      IF v_variant_id IS NOT NULL THEN
        SELECT stock INTO v_current_stock FROM public.product_variants WHERE id = v_variant_id FOR UPDATE;
        IF v_current_stock IS NULL OR v_current_stock < v_quantity THEN
          RAISE EXCEPTION 'Insufficient stock for % (Available: %, Requested: %)', v_product_name, COALESCE(v_current_stock, 0), v_quantity;
        END IF;
      ELSIF v_product_id IS NOT NULL THEN
        SELECT stock_quantity INTO v_current_stock FROM public.products WHERE id = v_product_id FOR UPDATE;
        IF v_current_stock IS NULL OR v_current_stock < v_quantity THEN
          RAISE EXCEPTION 'Insufficient stock for % (Available: %, Requested: %)', v_product_name, COALESCE(v_current_stock, 0), v_quantity;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- 2. Calculate Subtotal & Generate Invoice Number
  v_invoice_no := public.get_next_invoice_no();

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_quantity := COALESCE((v_item ->> 'quantity')::NUMERIC, 0);
    v_unit_price := COALESCE(
      (v_item ->> 'unit_price')::NUMERIC,
      (v_item ->> 'base_price')::NUMERIC,
      (v_item ->> 'price')::NUMERIC,
      0
    );
    v_line_total := COALESCE((v_item ->> 'line_total')::NUMERIC, ROUND(v_quantity * v_unit_price, 2));
    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  v_total := GREATEST(0, ROUND(v_subtotal + COALESCE(p_shipping, 0) + COALESCE(p_delivery_charge, 0) - COALESCE(p_discount_amount, 0), 2));

  -- 3. Insert Order Record
  INSERT INTO public.orders (
    invoice_no, user_id, customer_name, phone, address, items,
    subtotal, shipping, total, status, order_mode, order_type,
    delivery_charge, discount_amount, manual_discount_amount,
    manual_discount_type, manual_discount_value, coupon_code,
    coupon_percentage, total_gst, gst_amount, gst_enabled,
    payment_method, payment_mode, split_details, remarks,
    reference_number, billing_date, created_at, updated_at
  )
  VALUES (
    v_invoice_no, v_user_id, COALESCE(NULLIF(BTRIM(p_customer_name), ''), 'Customer'),
    COALESCE(p_phone, ''), COALESCE(p_address, ''), p_items,
    v_subtotal, COALESCE(p_shipping, 0), v_total, COALESCE(p_status, 'completed'),
    COALESCE(p_order_mode, 'offline'), COALESCE(p_order_type, 'pos_sale'),
    COALESCE(p_delivery_charge, 0), COALESCE(p_discount_amount, 0),
    COALESCE(p_manual_discount_amount, 0), COALESCE(p_manual_discount_type, 'flat'),
    COALESCE(p_manual_discount_value, 0), p_coupon_code,
    COALESCE(p_coupon_percentage, 0), COALESCE(p_total_gst, 0),
    COALESCE(p_total_gst, 0), COALESCE(p_gst_enabled, FALSE),
    COALESCE(p_payment_method, 'cash'), COALESCE(p_payment_method, 'cash'),
    COALESCE(p_split_details, '{}'::JSONB), p_remarks,
    p_reference_number, p_billing_date, v_created_at, NOW()
  )
  RETURNING id INTO v_order_id;

  -- 4. Insert Order Items, Deduct Stock & Record SALE Movements
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := NULLIF(v_item ->> 'product_id', '')::BIGINT;
    v_variant_id := NULLIF(v_item ->> 'variant_id', '')::UUID;
    v_quantity := COALESCE((v_item ->> 'quantity')::NUMERIC, 0);
    v_unit_price := COALESCE((v_item ->> 'unit_price')::NUMERIC, (v_item ->> 'base_price')::NUMERIC, 0);
    v_line_total := COALESCE((v_item ->> 'line_total')::NUMERIC, ROUND(v_quantity * v_unit_price, 2));
    v_product_name := COALESCE(v_item ->> 'product_name', v_item ->> 'name', 'Product');
    v_name_ta := COALESCE(v_item ->> 'product_tamil_name', v_item ->> 'tamil_name', '');
    v_unit := COALESCE(v_item ->> 'unit', 'piece');
    v_unit_type := COALESCE(v_item ->> 'unit_type', 'unit');
    v_base_quantity := COALESCE((v_item ->> 'base_quantity')::NUMERIC, 1);
    v_is_manual := COALESCE((v_item ->> 'is_manual')::BOOLEAN, FALSE);
    v_discount := COALESCE((v_item ->> 'discount')::NUMERIC, 0);
    v_gst_amount := COALESCE((v_item ->> 'gst_amount')::NUMERIC, 0);
    v_gst_rate := COALESCE((v_item ->> 'gst_rate')::NUMERIC, 0);
    v_image_url := v_item ->> 'image_url';
    v_variant_name := v_item ->> 'variant_name';
    v_source := COALESCE(v_item ->> 'source', 'catalogue');
    v_note := v_item ->> 'note';
    v_category := v_item ->> 'category';

    INSERT INTO public.order_items (
      order_id, product_id, variant_id, product_name, name,
      product_tamil_name, tamil_name, quantity, unit, unit_type,
      base_quantity, base_price, unit_price, line_total, image_url,
      is_manual, discount, gst_amount, gst_rate, variant_name,
      source, note, category, created_at
    )
    VALUES (
      v_order_id, v_product_id, v_variant_id, v_product_name, v_product_name,
      v_name_ta, v_name_ta, v_quantity, v_unit, v_unit_type,
      v_base_quantity, v_unit_price, v_unit_price, v_line_total, v_image_url,
      v_is_manual, v_discount, v_gst_amount, v_gst_rate, v_variant_name,
      v_source, v_note, v_category, v_created_at
    );

    -- Deduct Stock and Insert SALE Movement
    IF NOT v_is_manual AND v_quantity > 0 THEN
      IF v_variant_id IS NOT NULL THEN
        SELECT stock INTO v_current_stock FROM public.product_variants WHERE id = v_variant_id;
        SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE variant_id = v_variant_id AND is_active = TRUE LIMIT 1;

        UPDATE public.product_variants
        SET stock = GREATEST(0, stock - v_quantity), updated_at = NOW()
        WHERE id = v_variant_id;

        -- Parent aggregate update
        UPDATE public.products
        SET stock_quantity = (SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = v_product_id AND is_active = TRUE),
            stock = FLOOR((SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = v_product_id AND is_active = TRUE))::INTEGER,
            updated_at = NOW()
        WHERE id = v_product_id;

        INSERT INTO public.inventory_movements (
          product_id, variant_id, barcode_id, movement_type,
          quantity_delta, quantity_before, quantity_after,
          reference_type, reference_id, note
        )
        VALUES (
          v_product_id, v_variant_id, v_barcode_id, 'SALE',
          -v_quantity, v_current_stock, GREATEST(0, v_current_stock - v_quantity),
          'order', v_invoice_no, 'POS Sale checkout'
        );

      ELSIF v_product_id IS NOT NULL THEN
        SELECT stock_quantity INTO v_current_stock FROM public.products WHERE id = v_product_id;
        SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE product_id = v_product_id AND variant_id IS NULL AND is_active = TRUE LIMIT 1;

        UPDATE public.products
        SET stock_quantity = GREATEST(0, stock_quantity - v_quantity),
            stock = GREATEST(0, stock - FLOOR(v_quantity)::INTEGER),
            updated_at = NOW()
        WHERE id = v_product_id;

        INSERT INTO public.inventory_movements (
          product_id, variant_id, barcode_id, movement_type,
          quantity_delta, quantity_before, quantity_after,
          reference_type, reference_id, note
        )
        VALUES (
          v_product_id, NULL, v_barcode_id, 'SALE',
          -v_quantity, v_current_stock, GREATEST(0, v_current_stock - v_quantity),
          'order', v_invoice_no, 'POS Sale checkout'
        );
      END IF;
    END IF;
  END LOOP;

  -- 5. Increment Coupon Usage Count
  IF p_coupon_code IS NOT NULL AND BTRIM(p_coupon_code) <> '' THEN
    UPDATE public.coupons
    SET usage_count = usage_count + 1, updated_at = NOW()
    WHERE UPPER(BTRIM(code)) = UPPER(BTRIM(p_coupon_code));
  END IF;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'invoice_no', v_invoice_no,
    'total', v_total
  );
END;
$$;

-- 10. Update Store Settings Default to CLAD
UPDATE public.store_settings
SET name = 'CLAD',
    owner_name = 'Rubi krishna',
    phone = '+91 7010312145',
    email = 'cladclothing26@gmail.com',
    address = 'Manapparai, Trichy, Tamil Nadu - 621 306',
    updated_at = NOW()
WHERE id = 1;

COMMIT;

-- ============================================================
-- SECTION 13 / 23 — 20260903_0013_expense_tracker_addon.sql
-- ============================================================

-- ====================================================================
-- Migration 0013: Expense Tracker & Category Management Addon
-- ====================================================================

BEGIN;

-- 1. Expense Categories Table
CREATE TABLE IF NOT EXISTS public.expense_categories (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_expense_category_name UNIQUE (name)
);

-- 2. Seed Default Expense Categories
INSERT INTO public.expense_categories (name, is_active) VALUES
  ('Maintenance', TRUE),
  ('Marketing', TRUE),
  ('Other', TRUE),
  ('Rent', TRUE),
  ('Salaries', TRUE),
  ('Supplies', TRUE)
ON CONFLICT (name) DO NOTHING;

-- 3. Store Expenses Table
-- Note: category_id has ON DELETE SET NULL to preserve historical expense records even if a category is removed
CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  category_id BIGINT REFERENCES public.expense_categories(id) ON DELETE SET NULL,
  category_name TEXT NOT NULL, -- denormalized snapshot to protect historical records
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  description TEXT DEFAULT '',
  payment_mode TEXT DEFAULT 'cash', -- 'cash', 'upi', 'card', 'bank_transfer'
  recorded_by_name TEXT DEFAULT 'Staff',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Fast Query Indexes
CREATE INDEX IF NOT EXISTS idx_expenses_date ON public.expenses(expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON public.expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_expense_categories_active ON public.expense_categories(is_active);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS expense_categories_all ON public.expense_categories;
CREATE POLICY expense_categories_all ON public.expense_categories FOR ALL USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS expenses_all ON public.expenses;
CREATE POLICY expenses_all ON public.expenses FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 6. RPC: Summary Metric Calculation (Calculates Today, Week, Month, Year, All-Time)
CREATE OR REPLACE FUNCTION public.get_expense_summary_metrics(
  p_current_date DATE DEFAULT CURRENT_DATE
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
BEGIN
  SELECT 
    COALESCE(SUM(CASE WHEN expense_date = p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN expense_date >= v_week_start AND expense_date <= p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN expense_date >= v_month_start AND expense_date <= p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN expense_date >= v_year_start AND expense_date <= p_current_date THEN amount ELSE 0 END), 0),
    COALESCE(SUM(amount), 0)
  INTO
    v_today, v_this_week, v_this_month, v_this_year, v_total_all_time
  FROM public.expenses;

  RETURN jsonb_build_object(
    'today', v_today,
    'this_week', v_this_week,
    'this_month', v_this_month,
    'this_year', v_this_year,
    'total_all_time', v_total_all_time
  );
END;
$$;

COMMIT;

-- ============================================================
-- SECTION 14 / 23 — 20260904_0015_unregistered_category.sql
-- ============================================================

-- ============================================================================
-- Migration: 20260904_0015_unregistered_category.sql
-- Description: Seed system category 'Unregistered' for ad-hoc POS non-inventory billing
-- ============================================================================

DO $$
BEGIN
  -- Insert into categories if not present
  IF NOT EXISTS (
    SELECT 1 FROM public.categories 
    WHERE LOWER(name_en) = 'unregistered'
  ) THEN
    INSERT INTO public.categories (name_en, name_ta, is_active, sort_order)
    VALUES ('Unregistered', 'பதிவுசெய்யப்படாதது', TRUE, 999);
  END IF;
END $$;

-- ============================================================
-- SECTION 15 / 23 — 20260911_0016_rebrand_to_chaji_mens_wear.sql
-- ============================================================

-- Migration: 20260911_0016_rebrand_to_chaji_mens_wear.sql
-- Rebrand store details to YG ENTERPRISES and initialize branding storage bucket

BEGIN;

-- 1. Update Store Settings
UPDATE public.store_settings
SET name = 'YG ENTERPRISES',
    owner_name = 'Chandru ajitha',
    phone = '+91 8925094465, +91 9344159498',
    email = 'chandrums1552004@gmail.com',
    address = 'Manapparai, Trichy, Tamil Nadu - 621 306',
    updated_at = NOW()
WHERE id = 1;

-- 2. Create public 'branding' storage bucket if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'branding',
  'branding',
  TRUE,
  10485760,
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET
  public = TRUE,
  file_size_limit = 10485760;

-- 3. Storage Policies for branding bucket
DROP POLICY IF EXISTS branding_public_read ON storage.objects;
CREATE POLICY branding_public_read ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'branding');

DROP POLICY IF EXISTS branding_portal_upload ON storage.objects;
CREATE POLICY branding_portal_upload ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'branding');

DROP POLICY IF EXISTS branding_portal_update ON storage.objects;
CREATE POLICY branding_portal_update ON storage.objects
  FOR UPDATE TO anon, authenticated
  USING (bucket_id = 'branding')
  WITH CHECK (bucket_id = 'branding');

COMMIT;

-- ============================================================
-- SECTION 16 / 23 — 20260912_0017_update_store_address.sql
-- ============================================================

-- Migration: 20260912_0017_update_store_address.sql
-- Update store address for YG ENTERPRISES

BEGIN;

UPDATE public.store_settings
SET address = '1892 A, bypass road, Sevoor,arani-632316',
    updated_at = NOW()
WHERE id = 1;

COMMIT;

-- ============================================================
-- SECTION 17 / 23 — 20260917_0001_fix_soft_delete_unique_constraints.sql
-- ============================================================

-- Fix for products unique constraint
DROP INDEX IF EXISTS public.products_category_name_unique;
CREATE UNIQUE INDEX products_category_name_unique
  ON public.products (category_id, LOWER(BTRIM(name)))
  WHERE is_active = true;

-- Fix for variants unique constraint  
DROP INDEX IF EXISTS public.product_variants_product_name_unique;
CREATE UNIQUE INDEX product_variants_product_name_unique
  ON public.product_variants (product_id, LOWER(BTRIM(variant_name)))
  WHERE is_active = true;

-- ============================================================
-- SECTION 18 / 23 — 20260918_0018_advance_order_self_heal.sql
-- ============================================================

-- ============================================================
-- Migration 0018: Advance order self-healing & status integrity
-- Date: 2026-09-18
-- Purpose:
-- 1. Make complete_advance_order_v2 self-heal if invoice already generated
-- 2. Prevent update_advance_order_status from changing completed invoice orders
-- ============================================================

CREATE OR REPLACE FUNCTION public.complete_advance_order_v2(
  p_order_id uuid,
  p_payment_method text,
  p_final_amount numeric,
  p_coupon_code text DEFAULT NULL,
  p_coupon_percentage numeric DEFAULT 0,
  p_manual_discount numeric DEFAULT 0,
  p_remarks text DEFAULT ''
)
RETURNS TABLE(order_id uuid, invoice_no text, completed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_advance        public.advance_orders;
  v_order_id       uuid := gen_random_uuid();
  v_invoice        text;
  v_now            timestamptz := now();
  v_items          jsonb;
  v_item           jsonb;
  v_total_discount numeric := 0;
BEGIN
  -- Validate payment method
  IF lower(coalesce(p_payment_method, '')) NOT IN ('cash', 'upi', 'card') THEN
    RAISE EXCEPTION 'Select a valid payment method';
  END IF;

  -- Lock and fetch the advance order
  SELECT * INTO v_advance FROM public.advance_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Advance order not found';
  END IF;

  IF v_advance.status = 'cancelled' THEN
    RAISE EXCEPTION 'A cancelled order cannot be completed';
  END IF;

  -- Self-healing check: If invoice or completed order already exists, ensure completed status and return cleanly
  IF v_advance.completed_order_id IS NOT NULL OR v_advance.invoice_number IS NOT NULL THEN
    IF v_advance.status != 'completed' THEN
      UPDATE public.advance_orders
      SET status = 'completed',
          updated_at = v_now
      WHERE id = p_order_id;
    END IF;

    RETURN QUERY SELECT 
      coalesce(v_advance.completed_order_id, gen_random_uuid()),
      coalesce(v_advance.invoice_number, 'INV00000000'),
      coalesce(v_advance.completed_at, v_now);
    RETURN;
  END IF;

  -- Calculate total discount from manual discount and coupon
  v_total_discount := p_manual_discount + (v_advance.remaining_balance - p_manual_discount - p_final_amount);
  IF v_total_discount < 0 THEN
    v_total_discount := 0;
  END IF;

  -- Generate invoice number using the existing 8-digit sequence
  v_invoice := LPAD(nextval('public.invoice_number_seq')::TEXT, 8, '0');

  -- Build items JSONB - prefer products array, fall back to single product
  v_items := CASE
    WHEN jsonb_typeof(v_advance.products) = 'array' AND jsonb_array_length(v_advance.products) > 0
      THEN v_advance.products
    ELSE jsonb_build_array(
      jsonb_build_object(
        'name',        v_advance.product_name,
        'category',    v_advance.category,
        'description', v_advance.description,
        'quantity',    1,
        'base_price',  v_advance.total_amount,
        'line_total',  v_advance.total_amount,
        'unit',        'piece',
        'unit_type',   'unit',
        'source',      'advance_order'
      )
    )
  END;

  -- Create final sale order
  INSERT INTO public.orders (
    id, invoice_no, customer_name, phone, address, user_id,
    items, subtotal, total, status, order_mode, order_type,
    shipping, delivery_charge, discount_amount, manual_discount_amount,
    coupon_code, coupon_percentage, manual_discount_type, manual_discount_value,
    payment_mode, payment_method, created_at, updated_at
  ) VALUES (
    v_order_id, v_invoice,
    v_advance.customer_name, v_advance.phone, v_advance.address, auth.uid(),
    v_items, v_advance.total_amount, greatest(0, v_advance.total_amount - v_total_discount),
    'completed', 'offline', 'advance_order',
    0, 0, v_total_discount, p_manual_discount,
    p_coupon_code, p_coupon_percentage, 'flat', p_manual_discount,
    lower(p_payment_method), lower(p_payment_method),
    v_now, v_now
  );

  -- Insert order items
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    INSERT INTO public.order_items (
      order_id, product_name, name, quantity, unit, unit_type,
      base_price, line_total, is_manual
    ) VALUES (
      v_order_id,
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      greatest(coalesce((v_item->>'quantity')::numeric, 1), 0),
      coalesce(nullif(v_item->>'unit', ''), 'piece'),
      coalesce(nullif(v_item->>'unit_type', ''), 'unit'),
      greatest(coalesce((v_item->>'base_price')::numeric, 0), 0),
      greatest(coalesce((v_item->>'line_total')::numeric, 0), 0),
      false
    );
  END LOOP;

  -- Record final payment
  INSERT INTO public.advance_order_payments (
    advance_order_id, payment_type, amount, payment_method, remarks, received_by, received_at
  ) VALUES (
    p_order_id, 'remaining', p_final_amount,
    lower(p_payment_method), coalesce(p_remarks, ''), auth.uid(), v_now
  );

  -- Mark advance order as completed
  UPDATE public.advance_orders SET
    status               = 'completed',
    completed_at         = v_now,
    completed_order_id   = v_order_id,
    invoice_number       = v_invoice,
    final_payment_method = lower(p_payment_method),
    remarks              = CASE WHEN trim(coalesce(p_remarks, '')) = '' THEN remarks ELSE p_remarks END,
    updated_at           = v_now
  WHERE id = p_order_id;

  -- Timeline events
  INSERT INTO public.advance_order_timeline (
    advance_order_id, event_type, label, remarks, created_by, created_at
  ) VALUES
    (p_order_id, 'remaining_payment_received', 'Remaining Payment Received', coalesce(p_remarks, ''), auth.uid(), v_now),
    (p_order_id, 'invoice_generated',          'Invoice Generated',          v_invoice,               auth.uid(), v_now);

  RETURN QUERY SELECT v_order_id, v_invoice, v_now;
END;
$$;

-- Prevent changing status of advance orders that already have an invoice
CREATE OR REPLACE FUNCTION public.update_advance_order_status(
  p_order_id uuid,
  p_status   text,
  p_remarks  text DEFAULT ''
)
RETURNS SETOF public.advance_orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.advance_orders;
BEGIN
  SELECT * INTO v_order FROM public.advance_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Advance order % not found', p_order_id;
  END IF;

  IF (v_order.invoice_number IS NOT NULL OR v_order.completed_order_id IS NOT NULL) AND p_status != 'completed' THEN
    RAISE EXCEPTION 'Cannot change status of an order that already has an invoice generated';
  END IF;

  UPDATE public.advance_orders SET
    status     = p_status,
    remarks    = CASE WHEN trim(coalesce(p_remarks,'')) = '' THEN remarks ELSE p_remarks END,
    updated_at = now()
  WHERE id = p_order_id;

  INSERT INTO public.advance_order_timeline (advance_order_id, event_type, label, remarks, created_by, created_at)
  VALUES (
    p_order_id,
    p_status,
    CASE p_status
      WHEN 'pending_deposit'       THEN 'Status: Pending Deposit'
      WHEN 'waiting_final_payment' THEN 'Status: Waiting for Final Payment'
      WHEN 'ready_for_delivery'    THEN 'Status: Ready to Collect'
      WHEN 'completed'             THEN 'Order Completed'
      WHEN 'cancelled'             THEN 'Order Cancelled'
      ELSE p_status
    END,
    coalesce(p_remarks, ''),
    auth.uid(),
    now()
  );

  RETURN QUERY SELECT * FROM public.advance_orders WHERE id = p_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_advance_order_v2(uuid, text, numeric, text, numeric, numeric, text) TO public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_advance_order_status(uuid, text, text) TO authenticated, anon, public;

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- SECTION 19 / 23 — 20260918_0019_robust_public_invoice_lookup.sql
-- ============================================================

-- Migration: 20260918_0019_robust_public_invoice_lookup.sql
-- Enables get_public_invoice_by_number to seamlessly match invoices regardless of:
-- 1. "INV" prefix (e.g. "INV00000030" or "00000030")
-- 2. "PB-" legacy prefix (e.g. "PB-20260918-000001")
-- 3. Unpadded or stripped leading zeros (e.g. "30" matching "00000030")
-- 4. UUID order ID (e.g. from admin dashboard link)
-- 5. Case insensitivity and whitespace trimming

CREATE OR REPLACE FUNCTION public.get_public_invoice_by_number(p_invoice_no TEXT)
RETURNS SETOF public.orders
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM public.orders 
  WHERE invoice_no = NULLIF(BTRIM(p_invoice_no), '')
     OR LOWER(invoice_no) = LOWER(NULLIF(BTRIM(p_invoice_no), ''))
     OR invoice_no = REGEXP_REPLACE(BTRIM(p_invoice_no), '^(INV|PB)[-_ ]*', '', 'i')
     OR (
       REGEXP_REPLACE(BTRIM(p_invoice_no), '\D', '', 'g') <> ''
       AND invoice_no = LPAD(REGEXP_REPLACE(BTRIM(p_invoice_no), '\D', '', 'g'), 8, '0')
     )
     OR (
       REGEXP_REPLACE(BTRIM(p_invoice_no), '\D', '', 'g') <> ''
       AND invoice_no = REGEXP_REPLACE(REGEXP_REPLACE(BTRIM(p_invoice_no), '\D', '', 'g'), '^0+', '')
     )
     OR (
       p_invoice_no ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
       AND id = p_invoice_no::UUID
     )
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_public_invoice_by_number(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_invoice_by_number(TEXT) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- SECTION 20 / 23 — 20260924_0020_split_pos_branches.sql
-- ============================================================

-- ====================================================================
-- Migration 0020: Split POS into 2 fully isolated branches (pos1 / pos2)
-- Adds a `branch` column to catalog/order/inventory tables, gives each
-- branch its own invoice number sequence, and makes the POS sale RPCs
-- branch-aware. Idempotent: safe to re-run.
-- ====================================================================

BEGIN;

-- 1. Branch column on every branch-scoped table --------------------------

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';
ALTER TABLE public.product_variants ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';
ALTER TABLE public.inventory_movements ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';
ALTER TABLE public.barcode_registry ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';

DO $$
BEGIN
  ALTER TABLE public.products ADD CONSTRAINT products_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  ALTER TABLE public.product_variants ADD CONSTRAINT product_variants_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  ALTER TABLE public.categories ADD CONSTRAINT categories_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  ALTER TABLE public.orders ADD CONSTRAINT orders_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  ALTER TABLE public.inventory_movements ADD CONSTRAINT inventory_movements_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  ALTER TABLE public.barcode_registry ADD CONSTRAINT barcode_registry_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

CREATE INDEX IF NOT EXISTS products_branch_idx ON public.products(branch);
CREATE INDEX IF NOT EXISTS product_variants_branch_idx ON public.product_variants(branch);
CREATE INDEX IF NOT EXISTS categories_branch_idx ON public.categories(branch);
CREATE INDEX IF NOT EXISTS orders_branch_idx ON public.orders(branch, created_at DESC);
CREATE INDEX IF NOT EXISTS inventory_movements_branch_idx ON public.inventory_movements(branch, created_at DESC);

-- 2. Uniqueness must be scoped per branch now -----------------------------

DROP INDEX IF EXISTS public.products_category_name_unique;
CREATE UNIQUE INDEX IF NOT EXISTS products_category_name_unique
  ON public.products (branch, category_id, LOWER(BTRIM(name)))
  WHERE is_active = true;

DROP INDEX IF EXISTS public.product_variants_product_name_unique;
CREATE UNIQUE INDEX IF NOT EXISTS product_variants_product_name_unique
  ON public.product_variants (branch, product_id, LOWER(BTRIM(variant_name)))
  WHERE is_active = true;

-- 3. Per-branch invoice number sequences ----------------------------------
-- pos1 continues from wherever the shop's existing invoice_number_seq left
-- off; pos2 starts in a disjoint 8-digit range so numbers never collide
-- and the existing 8-digit display format needs no change.

CREATE SEQUENCE IF NOT EXISTS public.invoice_number_seq_pos1 START WITH 10000001;
CREATE SEQUENCE IF NOT EXISTS public.invoice_number_seq_pos2 START WITH 50000001;

DO $$
DECLARE
  v_old_last BIGINT;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'invoice_number_seq') THEN
    SELECT last_value INTO v_old_last FROM public.invoice_number_seq;
    IF v_old_last IS NOT NULL AND v_old_last >= 10000001 THEN
      PERFORM setval('public.invoice_number_seq_pos1', v_old_last, TRUE);
    END IF;
  END IF;
END;
$$;

DROP FUNCTION IF EXISTS public.get_next_invoice_no();

CREATE OR REPLACE FUNCTION public.get_next_invoice_no(p_branch TEXT DEFAULT 'pos1')
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
VOLATILE
AS $$
BEGIN
  IF p_branch = 'pos2' THEN
    RETURN LPAD(nextval('public.invoice_number_seq_pos2')::TEXT, 8, '0');
  ELSE
    RETURN LPAD(nextval('public.invoice_number_seq_pos1')::TEXT, 8, '0');
  END IF;
END;
$$;

-- 4. Branch-aware create_order_with_stock (fallback RPC) ------------------

DROP FUNCTION IF EXISTS public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC,
  TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, JSONB
);

CREATE OR REPLACE FUNCTION public.create_order_with_stock(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'pending',
  p_order_mode TEXT DEFAULT 'offline',
  p_order_type TEXT DEFAULT 'pos_sale',
  p_delivery_charge NUMERIC DEFAULT 0,
  p_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type TEXT DEFAULT 'flat',
  p_manual_discount_value NUMERIC DEFAULT 0,
  p_coupon_code TEXT DEFAULT NULL,
  p_coupon_percentage NUMERIC DEFAULT 0,
  p_total_gst NUMERIC DEFAULT 0,
  p_gst_enabled BOOLEAN DEFAULT FALSE,
  p_payment_method TEXT DEFAULT 'cash',
  p_split_details JSONB DEFAULT '{}'::JSONB,
  p_branch TEXT DEFAULT 'pos1'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC(12,2) := 0;
  v_total NUMERIC(12,2);
  v_item JSONB;
  v_quantity NUMERIC(12,3);
  v_price NUMERIC(12,2);
  v_line_total NUMERIC(12,2);
  v_source TEXT;
  v_attempt INTEGER;
  v_uses_typed_item_ids BOOLEAN;
  v_branch TEXT := CASE WHEN p_branch = 'pos2' THEN 'pos2' ELSE 'pos1' END;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'At least one order item is required';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_quantity := GREATEST(COALESCE(NULLIF(v_item ->> 'quantity', '')::NUMERIC, 0), 0);
    v_price := GREATEST(COALESCE(NULLIF(v_item ->> 'base_price', '')::NUMERIC, 0), 0);
    v_line_total := GREATEST(
      COALESCE(NULLIF(v_item ->> 'line_total', '')::NUMERIC, v_quantity * v_price),
      0
    );

    IF v_quantity <= 0 THEN
      RAISE EXCEPTION 'Item quantity must be greater than zero';
    END IF;

    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  v_total := GREATEST(
    ROUND(
      v_subtotal + GREATEST(COALESCE(p_shipping, 0), 0)
        + GREATEST(COALESCE(p_delivery_charge, 0), 0)
        + GREATEST(COALESCE(p_total_gst, 0), 0)
        - GREATEST(COALESCE(p_discount_amount, 0), 0)
        - GREATEST(COALESCE(p_manual_discount_amount, 0), 0),
      2
    ),
    0
  );

  SELECT data_type = 'bigint'
  INTO v_uses_typed_item_ids
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'order_items' AND column_name = 'product_id';

  FOR v_attempt IN 1..5 LOOP
    v_invoice_no := public.get_next_invoice_no(v_branch);
    v_order_id := gen_random_uuid();

    BEGIN
      INSERT INTO public.orders (
        id, invoice_no, user_id, customer_name, phone, address, items, subtotal, shipping, total,
        status, order_mode, order_type, delivery_charge, discount_amount, manual_discount_amount,
        manual_discount_type, manual_discount_value, coupon_code, coupon_percentage, total_gst,
        gst_amount, gst_enabled, payment_method, payment_mode, split_details, branch, created_at, updated_at
      ) VALUES (
        v_order_id, v_invoice_no, auth.uid(),
        COALESCE(NULLIF(BTRIM(p_customer_name), ''), 'Walk-in Customer'),
        COALESCE(BTRIM(p_phone), ''), COALESCE(NULLIF(BTRIM(p_address), ''), 'POS Counter'),
        p_items, v_subtotal, GREATEST(COALESCE(p_shipping, 0), 0), v_total,
        COALESCE(NULLIF(BTRIM(p_status), ''), 'pending'),
        COALESCE(NULLIF(BTRIM(p_order_mode), ''), 'offline'),
        COALESCE(NULLIF(BTRIM(p_order_type), ''), 'pos_sale'),
        GREATEST(COALESCE(p_delivery_charge, 0), 0),
        GREATEST(COALESCE(p_discount_amount, 0), 0),
        GREATEST(COALESCE(p_manual_discount_amount, 0), 0),
        COALESCE(NULLIF(BTRIM(p_manual_discount_type), ''), 'flat'),
        GREATEST(COALESCE(p_manual_discount_value, 0), 0),
        NULLIF(BTRIM(COALESCE(p_coupon_code, '')), ''),
        GREATEST(COALESCE(p_coupon_percentage, 0), 0),
        GREATEST(COALESCE(p_total_gst, 0), 0), GREATEST(COALESCE(p_total_gst, 0), 0),
        COALESCE(p_gst_enabled, FALSE),
        COALESCE(NULLIF(BTRIM(p_payment_method), ''), 'cash'),
        COALESCE(NULLIF(BTRIM(p_payment_method), ''), 'cash'),
        COALESCE(p_split_details, '{}'::JSONB), v_branch, NOW(), NOW()
      );
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      IF v_attempt = 5 THEN
        RAISE;
      END IF;
    END;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_quantity := GREATEST(COALESCE(NULLIF(v_item ->> 'quantity', '')::NUMERIC, 0), 0);
    v_price := GREATEST(COALESCE(NULLIF(v_item ->> 'base_price', '')::NUMERIC, 0), 0);
    v_line_total := GREATEST(
      COALESCE(NULLIF(v_item ->> 'line_total', '')::NUMERIC, v_quantity * v_price),
      0
    );
    v_source := COALESCE(NULLIF(v_item ->> 'source', ''), 'catalogue');

    IF v_uses_typed_item_ids THEN
      INSERT INTO public.order_items (
        order_id, product_id, variant_id, product_name, tamil_name, variant_name,
        quantity, unit, unit_price, line_total, is_manual, source, note
      ) VALUES (
        v_order_id, NULLIF(COALESCE(v_item ->> 'product_id', v_item ->> 'id'), '')::BIGINT,
        NULLIF(v_item ->> 'variant_id', '')::UUID, COALESCE(NULLIF(v_item ->> 'name', ''), 'Product'),
        NULLIF(v_item ->> 'tamil_name', ''), NULLIF(v_item ->> 'variant_name', ''),
        v_quantity, COALESCE(NULLIF(v_item ->> 'unit', ''), 'piece'), v_price, v_line_total,
        v_source = 'manual', v_source, NULLIF(v_item ->> 'note', '')
      );
    ELSE
      INSERT INTO public.order_items (
        order_id, product_id, variant_id, product_name, tamil_name, variant_name,
        quantity, unit, unit_price, line_total, is_manual, source, note
      ) VALUES (
        v_order_id, NULLIF(COALESCE(v_item ->> 'product_id', v_item ->> 'id'), ''),
        NULLIF(v_item ->> 'variant_id', ''), COALESCE(NULLIF(v_item ->> 'name', ''), 'Product'),
        NULLIF(v_item ->> 'tamil_name', ''), NULLIF(v_item ->> 'variant_name', ''),
        v_quantity, COALESCE(NULLIF(v_item ->> 'unit', ''), 'piece'), v_price, v_line_total,
        v_source = 'manual', v_source, NULLIF(v_item ->> 'note', '')
      );
    END IF;

    IF COALESCE(v_item ->> 'product_id', v_item ->> 'id', '') ~ '^[0-9]+$' THEN
      UPDATE public.products
      SET stock_quantity = GREATEST(stock_quantity - v_quantity, 0),
          stock = GREATEST(FLOOR(stock_quantity - v_quantity), 0)::INTEGER,
          updated_at = NOW()
      WHERE id::TEXT = COALESCE(v_item ->> 'product_id', v_item ->> 'id')
        AND branch = v_branch;
    END IF;

    IF NULLIF(v_item ->> 'variant_id', '') IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock = GREATEST(stock - v_quantity, 0), updated_at = NOW()
      WHERE id::TEXT = v_item ->> 'variant_id'
        AND branch = v_branch;
    END IF;
  END LOOP;

  IF NULLIF(BTRIM(COALESCE(p_coupon_code, '')), '') IS NOT NULL THEN
    UPDATE public.coupons
    SET usage_count = usage_count + 1
    WHERE UPPER(BTRIM(code)) = UPPER(BTRIM(p_coupon_code))
      AND is_active
      AND (usage_limit IS NULL OR usage_count < usage_limit);
  END IF;

  RETURN jsonb_build_object(
    'orderId', v_order_id,
    'invoiceNo', v_invoice_no,
    'createdAt', NOW()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC,
  TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, JSONB, TEXT
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_order_with_stock(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC,
  TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, BOOLEAN, TEXT, JSONB, TEXT
) TO anon, authenticated;

-- 5. Branch-aware complete_pos_sale_with_inventory (primary POS RPC) ------

DROP FUNCTION IF EXISTS public.complete_pos_sale_with_inventory(
  TEXT, TEXT, TEXT, JSONB, NUMERIC, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC,
  TEXT, NUMERIC, TEXT, NUMERIC, TEXT, JSONB, NUMERIC, BOOLEAN, TEXT, TEXT, TIMESTAMPTZ
);

CREATE OR REPLACE FUNCTION public.complete_pos_sale_with_inventory(
  p_customer_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_items JSONB,
  p_shipping NUMERIC DEFAULT 0,
  p_status TEXT DEFAULT 'completed',
  p_order_mode TEXT DEFAULT 'offline',
  p_order_type TEXT DEFAULT 'pos_sale',
  p_delivery_charge NUMERIC DEFAULT 0,
  p_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_amount NUMERIC DEFAULT 0,
  p_manual_discount_type TEXT DEFAULT 'flat',
  p_manual_discount_value NUMERIC DEFAULT 0,
  p_coupon_code TEXT DEFAULT NULL,
  p_coupon_percentage NUMERIC DEFAULT 0,
  p_payment_method TEXT DEFAULT 'cash',
  p_split_details JSONB DEFAULT '{}'::JSONB,
  p_total_gst NUMERIC DEFAULT 0,
  p_gst_enabled BOOLEAN DEFAULT FALSE,
  p_remarks TEXT DEFAULT NULL,
  p_reference_number TEXT DEFAULT NULL,
  p_billing_date TIMESTAMPTZ DEFAULT NULL,
  p_branch TEXT DEFAULT 'pos1'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_invoice_no TEXT;
  v_order_id UUID;
  v_subtotal NUMERIC := 0;
  v_total NUMERIC := 0;
  v_item JSONB;
  v_product_id BIGINT;
  v_variant_id UUID;
  v_quantity NUMERIC;
  v_unit_price NUMERIC;
  v_line_total NUMERIC;
  v_product_name TEXT;
  v_name_ta TEXT;
  v_unit TEXT;
  v_unit_type TEXT;
  v_base_quantity NUMERIC;
  v_is_manual BOOLEAN;
  v_discount NUMERIC;
  v_gst_amount NUMERIC;
  v_gst_rate NUMERIC;
  v_image_url TEXT;
  v_variant_name TEXT;
  v_source TEXT;
  v_note TEXT;
  v_category TEXT;
  v_current_stock NUMERIC;
  v_barcode_id UUID;
  v_created_at TIMESTAMPTZ := COALESCE(p_billing_date, NOW());
  v_branch TEXT := CASE WHEN p_branch = 'pos2' THEN 'pos2' ELSE 'pos1' END;
BEGIN
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order items cannot be empty';
  END IF;

  -- 1. Atomic Pre-Validation of Available Stock for All Items (branch-scoped)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := NULLIF(v_item ->> 'product_id', '')::BIGINT;
    v_variant_id := NULLIF(v_item ->> 'variant_id', '')::UUID;
    v_quantity := COALESCE((v_item ->> 'quantity')::NUMERIC, 0);
    v_is_manual := COALESCE((v_item ->> 'is_manual')::BOOLEAN, FALSE);
    v_product_name := COALESCE(v_item ->> 'product_name', v_item ->> 'name', 'Product');

    IF NOT v_is_manual AND v_quantity > 0 THEN
      IF v_variant_id IS NOT NULL THEN
        SELECT stock INTO v_current_stock FROM public.product_variants WHERE id = v_variant_id AND branch = v_branch FOR UPDATE;
        IF v_current_stock IS NULL OR v_current_stock < v_quantity THEN
          RAISE EXCEPTION 'Insufficient stock for % (Available: %, Requested: %)', v_product_name, COALESCE(v_current_stock, 0), v_quantity;
        END IF;
      ELSIF v_product_id IS NOT NULL THEN
        SELECT stock_quantity INTO v_current_stock FROM public.products WHERE id = v_product_id AND branch = v_branch FOR UPDATE;
        IF v_current_stock IS NULL OR v_current_stock < v_quantity THEN
          RAISE EXCEPTION 'Insufficient stock for % (Available: %, Requested: %)', v_product_name, COALESCE(v_current_stock, 0), v_quantity;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- 2. Calculate Subtotal & Generate Invoice Number (from this branch's sequence)
  v_invoice_no := public.get_next_invoice_no(v_branch);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_quantity := COALESCE((v_item ->> 'quantity')::NUMERIC, 0);
    v_unit_price := COALESCE(
      (v_item ->> 'unit_price')::NUMERIC,
      (v_item ->> 'base_price')::NUMERIC,
      (v_item ->> 'price')::NUMERIC,
      0
    );
    v_line_total := COALESCE((v_item ->> 'line_total')::NUMERIC, ROUND(v_quantity * v_unit_price, 2));
    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  v_total := GREATEST(0, ROUND(v_subtotal + COALESCE(p_shipping, 0) + COALESCE(p_delivery_charge, 0) - COALESCE(p_discount_amount, 0), 2));

  -- 3. Insert Order Record
  INSERT INTO public.orders (
    invoice_no, user_id, customer_name, phone, address, items,
    subtotal, shipping, total, status, order_mode, order_type,
    delivery_charge, discount_amount, manual_discount_amount,
    manual_discount_type, manual_discount_value, coupon_code,
    coupon_percentage, total_gst, gst_amount, gst_enabled,
    payment_method, payment_mode, split_details, remarks,
    reference_number, billing_date, branch, created_at, updated_at
  )
  VALUES (
    v_invoice_no, v_user_id, COALESCE(NULLIF(BTRIM(p_customer_name), ''), 'Customer'),
    COALESCE(p_phone, ''), COALESCE(p_address, ''), p_items,
    v_subtotal, COALESCE(p_shipping, 0), v_total, COALESCE(p_status, 'completed'),
    COALESCE(p_order_mode, 'offline'), COALESCE(p_order_type, 'pos_sale'),
    COALESCE(p_delivery_charge, 0), COALESCE(p_discount_amount, 0),
    COALESCE(p_manual_discount_amount, 0), COALESCE(p_manual_discount_type, 'flat'),
    COALESCE(p_manual_discount_value, 0), p_coupon_code,
    COALESCE(p_coupon_percentage, 0), COALESCE(p_total_gst, 0),
    COALESCE(p_total_gst, 0), COALESCE(p_gst_enabled, FALSE),
    COALESCE(p_payment_method, 'cash'), COALESCE(p_payment_method, 'cash'),
    COALESCE(p_split_details, '{}'::JSONB), p_remarks,
    p_reference_number, p_billing_date, v_branch, v_created_at, NOW()
  )
  RETURNING id INTO v_order_id;

  -- 4. Insert Order Items, Deduct Stock (branch-scoped) & Record SALE Movements
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := NULLIF(v_item ->> 'product_id', '')::BIGINT;
    v_variant_id := NULLIF(v_item ->> 'variant_id', '')::UUID;
    v_quantity := COALESCE((v_item ->> 'quantity')::NUMERIC, 0);
    v_unit_price := COALESCE((v_item ->> 'unit_price')::NUMERIC, (v_item ->> 'base_price')::NUMERIC, 0);
    v_line_total := COALESCE((v_item ->> 'line_total')::NUMERIC, ROUND(v_quantity * v_unit_price, 2));
    v_product_name := COALESCE(v_item ->> 'product_name', v_item ->> 'name', 'Product');
    v_name_ta := COALESCE(v_item ->> 'product_tamil_name', v_item ->> 'tamil_name', '');
    v_unit := COALESCE(v_item ->> 'unit', 'piece');
    v_unit_type := COALESCE(v_item ->> 'unit_type', 'unit');
    v_base_quantity := COALESCE((v_item ->> 'base_quantity')::NUMERIC, 1);
    v_is_manual := COALESCE((v_item ->> 'is_manual')::BOOLEAN, FALSE);
    v_discount := COALESCE((v_item ->> 'discount')::NUMERIC, 0);
    v_gst_amount := COALESCE((v_item ->> 'gst_amount')::NUMERIC, 0);
    v_gst_rate := COALESCE((v_item ->> 'gst_rate')::NUMERIC, 0);
    v_image_url := v_item ->> 'image_url';
    v_variant_name := v_item ->> 'variant_name';
    v_source := COALESCE(v_item ->> 'source', 'catalogue');
    v_note := v_item ->> 'note';
    v_category := v_item ->> 'category';

    INSERT INTO public.order_items (
      order_id, product_id, variant_id, product_name, name,
      product_tamil_name, tamil_name, quantity, unit, unit_type,
      base_quantity, base_price, unit_price, line_total, image_url,
      is_manual, discount, gst_amount, gst_rate, variant_name,
      source, note, category, created_at
    )
    VALUES (
      v_order_id, v_product_id, v_variant_id, v_product_name, v_product_name,
      v_name_ta, v_name_ta, v_quantity, v_unit, v_unit_type,
      v_base_quantity, v_unit_price, v_unit_price, v_line_total, v_image_url,
      v_is_manual, v_discount, v_gst_amount, v_gst_rate, v_variant_name,
      v_source, v_note, v_category, v_created_at
    );

    -- Deduct Stock and Insert SALE Movement (branch-scoped)
    IF NOT v_is_manual AND v_quantity > 0 THEN
      IF v_variant_id IS NOT NULL THEN
        SELECT stock INTO v_current_stock FROM public.product_variants WHERE id = v_variant_id AND branch = v_branch;
        SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE variant_id = v_variant_id AND is_active = TRUE LIMIT 1;

        UPDATE public.product_variants
        SET stock = GREATEST(0, stock - v_quantity), updated_at = NOW()
        WHERE id = v_variant_id AND branch = v_branch;

        -- Parent aggregate update
        UPDATE public.products
        SET stock_quantity = (SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = v_product_id AND is_active = TRUE),
            stock = FLOOR((SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = v_product_id AND is_active = TRUE))::INTEGER,
            updated_at = NOW()
        WHERE id = v_product_id AND branch = v_branch;

        INSERT INTO public.inventory_movements (
          product_id, variant_id, barcode_id, movement_type,
          quantity_delta, quantity_before, quantity_after,
          reference_type, reference_id, note, branch
        )
        VALUES (
          v_product_id, v_variant_id, v_barcode_id, 'SALE',
          -v_quantity, v_current_stock, GREATEST(0, v_current_stock - v_quantity),
          'order', v_invoice_no, 'POS Sale checkout', v_branch
        );

      ELSIF v_product_id IS NOT NULL THEN
        SELECT stock_quantity INTO v_current_stock FROM public.products WHERE id = v_product_id AND branch = v_branch;
        SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE product_id = v_product_id AND variant_id IS NULL AND is_active = TRUE LIMIT 1;

        UPDATE public.products
        SET stock_quantity = GREATEST(0, stock_quantity - v_quantity),
            stock = GREATEST(0, stock - FLOOR(v_quantity)::INTEGER),
            updated_at = NOW()
        WHERE id = v_product_id AND branch = v_branch;

        INSERT INTO public.inventory_movements (
          product_id, variant_id, barcode_id, movement_type,
          quantity_delta, quantity_before, quantity_after,
          reference_type, reference_id, note, branch
        )
        VALUES (
          v_product_id, NULL, v_barcode_id, 'SALE',
          -v_quantity, v_current_stock, GREATEST(0, v_current_stock - v_quantity),
          'order', v_invoice_no, 'POS Sale checkout', v_branch
        );
      END IF;
    END IF;
  END LOOP;

  -- 5. Increment Coupon Usage Count (coupons remain shared across branches)
  IF p_coupon_code IS NOT NULL AND BTRIM(p_coupon_code) <> '' THEN
    UPDATE public.coupons
    SET usage_count = usage_count + 1, updated_at = NOW()
    WHERE UPPER(BTRIM(code)) = UPPER(BTRIM(p_coupon_code));
  END IF;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'invoice_no', v_invoice_no,
    'total', v_total
  );
END;
$$;

-- 6. Advance orders (deposit-based custom orders) must also be branch-scoped:
-- completing one allocates an invoice number, so it has to draw from the same
-- per-branch sequence as regular POS sales or numbers would collide/cross-book.

ALTER TABLE public.advance_orders ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'pos1';

DO $$
BEGIN
  ALTER TABLE public.advance_orders ADD CONSTRAINT advance_orders_branch_check CHECK (branch IN ('pos1', 'pos2'));
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

CREATE INDEX IF NOT EXISTS advance_orders_branch_idx ON public.advance_orders(branch, created_at DESC);

DROP FUNCTION IF EXISTS public.create_advance_order(text,text,text,text,text,text,numeric,numeric,date,text,text,text,jsonb);

CREATE OR REPLACE FUNCTION public.create_advance_order(
  p_customer_name text, p_phone text, p_address text, p_product_name text,
  p_category text, p_description text, p_total_amount numeric, p_deposit_amount numeric,
  p_expected_delivery_date date, p_remarks text, p_payment_method text, p_created_by_name text,
  p_products jsonb DEFAULT '[]'::jsonb,
  p_branch text DEFAULT 'pos1'
)
RETURNS public.advance_orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_order public.advance_orders; v_now timestamptz := now(); v_deposit_id text; v_branch text := CASE WHEN p_branch = 'pos2' THEN 'pos2' ELSE 'pos1' END;
BEGIN
  IF trim(coalesce(p_customer_name,'')) = '' THEN RAISE EXCEPTION 'Customer name is required'; END IF;
  IF trim(coalesce(p_phone,'')) = '' THEN RAISE EXCEPTION 'Phone number is required'; END IF;
  IF trim(coalesce(p_product_name,'')) = '' THEN RAISE EXCEPTION 'Product name is required'; END IF;
  IF coalesce(p_total_amount,0) <= 0 THEN RAISE EXCEPTION 'Total amount must be greater than zero'; END IF;
  IF coalesce(p_deposit_amount,0) <= 0 OR p_deposit_amount >= p_total_amount THEN RAISE EXCEPTION 'Deposit must be greater than zero and less than the total amount'; END IF;
  IF lower(coalesce(p_payment_method,'')) NOT IN ('cash','upi','card') THEN RAISE EXCEPTION 'Select a valid deposit payment method'; END IF;
  v_deposit_id := 'DEP-' || to_char(v_now at time zone 'Asia/Kolkata','YYYYMMDD') || '-' || lpad(nextval('public.deposit_number_seq')::text,4,'0');
  INSERT INTO public.advance_orders(deposit_id,customer_name,phone,address,product_name,products,category,description,total_amount,deposit_amount,expected_delivery_date,remarks,created_by,created_by_name,created_at,updated_at,branch)
  VALUES(v_deposit_id,trim(p_customer_name),trim(p_phone),trim(coalesce(p_address,'')),trim(p_product_name),CASE WHEN jsonb_typeof(coalesce(p_products,'[]'::jsonb))='array' THEN coalesce(p_products,'[]'::jsonb) ELSE '[]'::jsonb END,trim(coalesce(p_category,'')),trim(coalesce(p_description,'')),round(p_total_amount,2),round(p_deposit_amount,2),p_expected_delivery_date,trim(coalesce(p_remarks,'')),auth.uid(),trim(coalesce(p_created_by_name,'')),v_now,v_now,v_branch)
  RETURNING * INTO v_order;
  INSERT INTO public.advance_order_payments(advance_order_id,payment_type,amount,payment_method,remarks,received_by,received_at)
  VALUES(v_order.id,'deposit',v_order.deposit_amount,lower(p_payment_method),coalesce(p_remarks,''),auth.uid(),v_now);
  INSERT INTO public.advance_order_timeline(advance_order_id,event_type,label,created_by,created_at) VALUES
    (v_order.id,'created','Created',auth.uid(),v_now),
    (v_order.id,'deposit_received','Deposit Received',auth.uid(),v_now);
  RETURN v_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_advance_order(text,text,text,text,text,text,numeric,numeric,date,text,text,text,jsonb,text) TO anon, authenticated;

-- Redefine the (self-healing) completion RPC to derive branch from the advance
-- order itself — safer than trusting a client-supplied branch — and to pull
-- the invoice number from that branch's sequence via get_next_invoice_no()
-- instead of hitting the old shared invoice_number_seq directly (which would
-- otherwise collide with regular POS sales once branches have separate sequences).
CREATE OR REPLACE FUNCTION public.complete_advance_order_v2(
  p_order_id uuid,
  p_payment_method text,
  p_final_amount numeric,
  p_coupon_code text DEFAULT NULL,
  p_coupon_percentage numeric DEFAULT 0,
  p_manual_discount numeric DEFAULT 0,
  p_remarks text DEFAULT ''
)
RETURNS TABLE(order_id uuid, invoice_no text, completed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_advance        public.advance_orders;
  v_order_id       uuid := gen_random_uuid();
  v_invoice        text;
  v_now            timestamptz := now();
  v_items          jsonb;
  v_item           jsonb;
  v_total_discount numeric := 0;
  v_branch         text;
BEGIN
  IF lower(coalesce(p_payment_method, '')) NOT IN ('cash', 'upi', 'card') THEN
    RAISE EXCEPTION 'Select a valid payment method';
  END IF;

  SELECT * INTO v_advance FROM public.advance_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Advance order not found';
  END IF;

  v_branch := CASE WHEN v_advance.branch = 'pos2' THEN 'pos2' ELSE 'pos1' END;

  IF v_advance.status = 'cancelled' THEN
    RAISE EXCEPTION 'A cancelled order cannot be completed';
  END IF;

  IF v_advance.completed_order_id IS NOT NULL OR v_advance.invoice_number IS NOT NULL THEN
    IF v_advance.status != 'completed' THEN
      UPDATE public.advance_orders
      SET status = 'completed',
          updated_at = v_now
      WHERE id = p_order_id;
    END IF;

    RETURN QUERY SELECT
      coalesce(v_advance.completed_order_id, gen_random_uuid()),
      coalesce(v_advance.invoice_number, 'INV00000000'),
      coalesce(v_advance.completed_at, v_now);
    RETURN;
  END IF;

  v_total_discount := p_manual_discount + (v_advance.remaining_balance - p_manual_discount - p_final_amount);
  IF v_total_discount < 0 THEN
    v_total_discount := 0;
  END IF;

  v_invoice := public.get_next_invoice_no(v_branch);

  v_items := CASE
    WHEN jsonb_typeof(v_advance.products) = 'array' AND jsonb_array_length(v_advance.products) > 0
      THEN v_advance.products
    ELSE jsonb_build_array(
      jsonb_build_object(
        'name',        v_advance.product_name,
        'category',    v_advance.category,
        'description', v_advance.description,
        'quantity',    1,
        'base_price',  v_advance.total_amount,
        'line_total',  v_advance.total_amount,
        'unit',        'piece',
        'unit_type',   'unit',
        'source',      'advance_order'
      )
    )
  END;

  INSERT INTO public.orders (
    id, invoice_no, customer_name, phone, address, user_id,
    items, subtotal, total, status, order_mode, order_type,
    shipping, delivery_charge, discount_amount, manual_discount_amount,
    coupon_code, coupon_percentage, manual_discount_type, manual_discount_value,
    payment_mode, payment_method, branch, created_at, updated_at
  ) VALUES (
    v_order_id, v_invoice,
    v_advance.customer_name, v_advance.phone, v_advance.address, auth.uid(),
    v_items, v_advance.total_amount, greatest(0, v_advance.total_amount - v_total_discount),
    'completed', 'offline', 'advance_order',
    0, 0, v_total_discount, p_manual_discount,
    p_coupon_code, p_coupon_percentage, 'flat', p_manual_discount,
    lower(p_payment_method), lower(p_payment_method), v_branch,
    v_now, v_now
  );

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    INSERT INTO public.order_items (
      order_id, product_name, name, quantity, unit, unit_type,
      base_price, line_total, is_manual
    ) VALUES (
      v_order_id,
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      coalesce(nullif(trim(v_item->>'name'), ''), 'Product'),
      greatest(coalesce((v_item->>'quantity')::numeric, 1), 0),
      coalesce(nullif(v_item->>'unit', ''), 'piece'),
      coalesce(nullif(v_item->>'unit_type', ''), 'unit'),
      greatest(coalesce((v_item->>'base_price')::numeric, 0), 0),
      greatest(coalesce((v_item->>'line_total')::numeric, 0), 0),
      false
    );
  END LOOP;

  INSERT INTO public.advance_order_payments (
    advance_order_id, payment_type, amount, payment_method, remarks, received_by, received_at
  ) VALUES (
    p_order_id, 'remaining', p_final_amount,
    lower(p_payment_method), coalesce(p_remarks, ''), auth.uid(), v_now
  );

  UPDATE public.advance_orders SET
    status               = 'completed',
    completed_at         = v_now,
    completed_order_id   = v_order_id,
    invoice_number       = v_invoice,
    final_payment_method = lower(p_payment_method),
    remarks              = CASE WHEN trim(coalesce(p_remarks, '')) = '' THEN remarks ELSE p_remarks END,
    updated_at           = v_now
  WHERE id = p_order_id;

  INSERT INTO public.advance_order_timeline (
    advance_order_id, event_type, label, remarks, created_by, created_at
  ) VALUES
    (p_order_id, 'remaining_payment_received', 'Remaining Payment Received', coalesce(p_remarks, ''), auth.uid(), v_now),
    (p_order_id, 'invoice_generated',          'Invoice Generated',          v_invoice,               auth.uid(), v_now);

  RETURN QUERY SELECT v_order_id, v_invoice, v_now;
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_advance_order_v2(uuid, text, numeric, text, numeric, numeric, text) TO public, anon, authenticated;

-- 7. Give POS 1 and POS 2 visibly different auto-generated barcode values.
-- POS 1 keeps the exact prefix/sequence it already had ('PBP'/'PBV', same
-- barcode_product_seq/barcode_variant_seq) so nothing about barcodes you've
-- already generated or printed changes. POS 2 gets its own fresh sequences
-- and a distinct 'P2P'/'P2V' prefix, so a scanned code instantly tells you
-- which branch it belongs to. Existing barcode_registry rows are untouched —
-- this only changes what NEW barcodes look like going forward.

CREATE SEQUENCE IF NOT EXISTS public.barcode_product_seq_pos2 START WITH 10000001;
CREATE SEQUENCE IF NOT EXISTS public.barcode_variant_seq_pos2 START WITH 10000001;

DROP FUNCTION IF EXISTS public.generate_barcode_value(TEXT);

CREATE OR REPLACE FUNCTION public.generate_barcode_value(p_entity_type TEXT, p_branch TEXT DEFAULT 'pos1')
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_branch = 'pos2' THEN
    IF p_entity_type = 'variant' THEN
      RETURN 'P2V' || LPAD(nextval('public.barcode_variant_seq_pos2')::TEXT, 8, '0');
    ELSE
      RETURN 'P2P' || LPAD(nextval('public.barcode_product_seq_pos2')::TEXT, 8, '0');
    END IF;
  ELSE
    -- POS 1: unchanged from before the branch split.
    IF p_entity_type = 'variant' THEN
      RETURN 'PBV' || LPAD(nextval('public.barcode_variant_seq')::TEXT, 8, '0');
    ELSE
      RETURN 'PBP' || LPAD(nextval('public.barcode_product_seq')::TEXT, 8, '0');
    END IF;
  END IF;
END;
$$;

-- 8. Fix inventory_movements.branch on barcode receipt / stock adjustment
-- RPCs: these never took a branch param and would otherwise leave every
-- movement defaulted to 'pos1' regardless of which branch's stock moved.
-- Derive the branch from the product/variant row being touched instead.

CREATE OR REPLACE FUNCTION public.create_barcode_and_receive_stock(
  p_product_id BIGINT,
  p_variant_id UUID DEFAULT NULL,
  p_quantity_received NUMERIC DEFAULT 0,
  p_unit_cost NUMERIC DEFAULT NULL,
  p_created_by_name TEXT DEFAULT '',
  p_custom_barcode TEXT DEFAULT NULL,
  p_note TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_entity_type TEXT;
  v_barcode_id UUID;
  v_barcode_value TEXT;
  v_is_new_barcode BOOLEAN := FALSE;
  v_movement_type TEXT;
  v_qty_before NUMERIC := 0;
  v_qty_after NUMERIC := 0;
  v_prod_name TEXT;
  v_var_name TEXT := '';
  v_branch TEXT;
BEGIN
  IF p_quantity_received < 0 THEN
    RAISE EXCEPTION 'Quantity received cannot be negative';
  END IF;

  -- 1. Check Parent Product Exists (and capture its branch)
  SELECT name, branch INTO v_prod_name, v_branch FROM public.products WHERE id = p_product_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product with ID % not found', p_product_id;
  END IF;

  -- 2. Verify Variant Belongs to Product if Variant is Provided
  IF p_variant_id IS NOT NULL THEN
    v_entity_type := 'variant';
    SELECT variant_name, stock INTO v_var_name, v_qty_before
    FROM public.product_variants
    WHERE id = p_variant_id AND product_id = p_product_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant % does not belong to Product %', p_variant_id, p_product_id;
    END IF;
  ELSE
    v_entity_type := 'product';
    SELECT stock_quantity INTO v_qty_before
    FROM public.products
    WHERE id = p_product_id;
  END IF;

  -- 3. Check for Existing Active Barcode in barcode_registry (SKU Identity)
  IF v_entity_type = 'variant' THEN
    SELECT id, barcode_value INTO v_barcode_id, v_barcode_value
    FROM public.barcode_registry
    WHERE variant_id = p_variant_id AND is_active = TRUE
    ORDER BY created_at DESC
    LIMIT 1;
  ELSE
    SELECT id, barcode_value INTO v_barcode_id, v_barcode_value
    FROM public.barcode_registry
    WHERE product_id = p_product_id AND variant_id IS NULL AND is_active = TRUE
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  -- 4. Reuse Existing or Create New Barcode
  IF v_barcode_id IS NOT NULL THEN
    v_is_new_barcode := FALSE;
    v_movement_type := CASE WHEN v_qty_before = 0 THEN 'INITIAL_BARCODE_STOCK' ELSE 'RESTOCK' END;
  ELSE
    v_is_new_barcode := TRUE;
    v_movement_type := 'INITIAL_BARCODE_STOCK';
    v_barcode_value := COALESCE(NULLIF(UPPER(BTRIM(p_custom_barcode)), ''), public.generate_barcode_value(v_entity_type, v_branch));

    INSERT INTO public.barcode_registry (
      barcode_value, entity_type, product_id, variant_id, is_active, created_by_name, branch
    )
    VALUES (
      v_barcode_value, v_entity_type, p_product_id, p_variant_id, TRUE, COALESCE(p_created_by_name, ''), v_branch
    )
    RETURNING id INTO v_barcode_id;
  END IF;

  -- 5. Synchronize compatibility column on target table
  IF v_entity_type = 'variant' THEN
    UPDATE public.product_variants
    SET barcode = v_barcode_value, updated_at = NOW()
    WHERE id = p_variant_id;
  ELSE
    UPDATE public.products
    SET barcode = v_barcode_value, updated_at = NOW()
    WHERE id = p_product_id;
  END IF;

  -- 6. Apply Stock Increment & Parent Aggregate Sync
  v_qty_after := v_qty_before + p_quantity_received;

  IF p_quantity_received > 0 THEN
    IF v_entity_type = 'variant' THEN
      UPDATE public.product_variants
      SET stock = v_qty_after, updated_at = NOW()
      WHERE id = p_variant_id;

      -- Refresh parent aggregate stock cache
      UPDATE public.products
      SET stock_quantity = (
            SELECT COALESCE(SUM(stock), 0)
            FROM public.product_variants
            WHERE product_id = p_product_id AND is_active = TRUE
          ),
          stock = FLOOR((
            SELECT COALESCE(SUM(stock), 0)
            FROM public.product_variants
            WHERE product_id = p_product_id AND is_active = TRUE
          ))::INTEGER,
          updated_at = NOW()
      WHERE id = p_product_id;
    ELSE
      UPDATE public.products
      SET stock_quantity = v_qty_after,
          stock = FLOOR(v_qty_after)::INTEGER,
          updated_at = NOW()
      WHERE id = p_product_id;
    END IF;
  END IF;

  -- 7. Record Immutable Inventory Movement
  IF p_quantity_received > 0 THEN
    INSERT INTO public.inventory_movements (
      product_id, variant_id, barcode_id, movement_type,
      quantity_delta, quantity_before, quantity_after,
      unit_cost, reference_type, reference_id, note, created_by_name, branch
    )
    VALUES (
      p_product_id, p_variant_id, v_barcode_id, v_movement_type,
      p_quantity_received, v_qty_before, v_qty_after,
      p_unit_cost, 'barcode_receipt', v_barcode_value,
      COALESCE(p_note, ''), COALESCE(p_created_by_name, ''), v_branch
    );
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'barcode_id', v_barcode_id,
    'barcode_value', v_barcode_value,
    'is_new_barcode', v_is_new_barcode,
    'movement_type', v_movement_type,
    'quantity_before', v_qty_before,
    'quantity_received', p_quantity_received,
    'quantity_after', v_qty_after,
    'product_id', p_product_id,
    'variant_id', p_variant_id,
    'product_name', v_prod_name,
    'variant_name', v_var_name
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.adjust_inventory_stock(
  p_product_id BIGINT,
  p_variant_id UUID DEFAULT NULL,
  p_new_quantity NUMERIC DEFAULT 0,
  p_reason TEXT DEFAULT 'RESTOCK',
  p_note TEXT DEFAULT '',
  p_created_by_name TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qty_before NUMERIC := 0;
  v_delta NUMERIC := 0;
  v_barcode_id UUID;
  v_branch TEXT;
BEGIN
  IF p_new_quantity < 0 THEN
    RAISE EXCEPTION 'Stock quantity cannot be negative';
  END IF;

  -- Verify variant if supplied
  IF p_variant_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.product_variants WHERE id = p_variant_id AND product_id = p_product_id) THEN
      RAISE EXCEPTION 'Variant does not belong to specified Product';
    END IF;

    SELECT stock, branch INTO v_qty_before, v_branch FROM public.product_variants WHERE id = p_variant_id FOR UPDATE;
    SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE variant_id = p_variant_id AND is_active = TRUE LIMIT 1;

    v_delta := p_new_quantity - v_qty_before;

    UPDATE public.product_variants
    SET stock = p_new_quantity, updated_at = NOW()
    WHERE id = p_variant_id;

    -- Refresh parent aggregate
    UPDATE public.products
    SET stock_quantity = (SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = p_product_id AND is_active = TRUE),
        stock = FLOOR((SELECT COALESCE(SUM(stock), 0) FROM public.product_variants WHERE product_id = p_product_id AND is_active = TRUE))::INTEGER,
        updated_at = NOW()
    WHERE id = p_product_id;
  ELSE
    SELECT stock_quantity, branch INTO v_qty_before, v_branch FROM public.products WHERE id = p_product_id FOR UPDATE;
    SELECT id INTO v_barcode_id FROM public.barcode_registry WHERE product_id = p_product_id AND variant_id IS NULL AND is_active = TRUE LIMIT 1;

    v_delta := p_new_quantity - v_qty_before;

    UPDATE public.products
    SET stock_quantity = p_new_quantity,
        stock = FLOOR(p_new_quantity)::INTEGER,
        updated_at = NOW()
    WHERE id = p_product_id;
  END IF;

  -- Record Movement
  INSERT INTO public.inventory_movements (
    product_id, variant_id, barcode_id, movement_type,
    quantity_delta, quantity_before, quantity_after,
    reference_type, note, created_by_name, branch
  )
  VALUES (
    p_product_id, p_variant_id, v_barcode_id, p_reason,
    v_delta, v_qty_before, p_new_quantity,
    'adjustment', COALESCE(p_note, ''), COALESCE(p_created_by_name, ''), v_branch
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'quantity_before', v_qty_before,
    'quantity_after', p_new_quantity,
    'delta', v_delta,
    'reason', p_reason
  );
END;
$$;

COMMIT;

-- ============================================================
-- SECTION 21 / 23 — 20260925_0021_cleanup_legacy_chaji_data.sql
-- ============================================================

-- ====================================================================
-- Migration 0021: Remove legacy CHAJI MENS WEAR data before seeding the
-- new YG Enterprises branch catalogs (migration 0022).
--
-- Scope, deliberately conservative:
--  - Clears the old product/variant/barcode/category catalog (all of it —
--    every row currently in these tables predates the YG rebrand and is
--    CHAJI menswear stock).
--  - Resets the store_settings row (name/owner/phone/email/address) to
--    YG Enterprises' real details.
--  - Empties the unused 'branding' storage bucket created for CHAJI.
--
-- Deliberately NOT touched: `orders` / `order_items` (real historical
-- sales/financial records survive regardless of brand — order_items
-- already stores product_name redundantly, and orders.product_id uses
-- ON DELETE SET NULL, so deleting the old catalog does not corrupt past
-- receipts) and `coupons` (not brand-specific).
-- ====================================================================

BEGIN;

-- 1. Clear the legacy product catalog (respecting FK delete order:
-- barcode_registry -> RESTRICT on product_id/variant_id, so it must go
-- first; product_variants and inventory_movements reference products
-- with CASCADE / SET NULL respectively, so those are safe once
-- barcode_registry is clear).
DELETE FROM public.barcode_registry;
DELETE FROM public.product_variants;
DELETE FROM public.products;
DELETE FROM public.categories;

-- 2. Reset store contact details to YG Enterprises (src/lib/brand.ts is the
-- client-side source of truth these values are kept in sync with).
UPDATE public.store_settings
SET name = 'YG ENTERPRISES',
    owner_name = 'M. Gurumoorthy',
    phone = '+91 98844 10700, +91 97878 08090',
    email = 'ygenterprises2000@gmail.com',
    address = '#189, N.S.C. Bose Road, (Opp. Bus Depot, Hotel Sankar Cafe Building), Chennai - 600 001',
    updated_at = NOW()
WHERE id = 1;

-- 3. NOTE: any leftover files in the 'branding' storage bucket (created for
-- CHAJI in migration 0016) are intentionally left alone here — Supabase
-- blocks direct `DELETE FROM storage.objects` with a protective trigger
-- ("Direct deletion from storage tables is not allowed"). Nothing in this
-- app reads from that bucket, so stray files there are harmless; clear them
-- from the Supabase Dashboard -> Storage -> branding (or the Storage API)
-- if you want it empty.

COMMIT;

-- ============================================================
-- SECTION 22 / 23 — 20260925_0022_seed_branch_starter_catalog.sql
-- ============================================================

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

-- ============================================================
-- SECTION 23 / 23 — 20260926_0023_branch_settings_and_attendance.sql
-- ============================================================

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

