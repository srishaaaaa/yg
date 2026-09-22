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
