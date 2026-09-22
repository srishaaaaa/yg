-- Migration: 20260912_0017_update_store_address.sql
-- Update store address for YG ENTERPRISES

BEGIN;

UPDATE public.store_settings
SET address = '1892 A, bypass road, Sevoor,arani-632316',
    updated_at = NOW()
WHERE id = 1;

COMMIT;
