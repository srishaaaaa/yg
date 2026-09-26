-- ====================================================================
-- Migration 0028: Add Website URL to Store Settings
--
-- Adds website_url column to store_settings table for storing the official
-- company website URL, used in invoices and WhatsApp messages.
-- ====================================================================

BEGIN;

ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS website_url TEXT NOT NULL DEFAULT 'https://ygenterprises.co.in';

-- Update both store settings rows with the official website
UPDATE public.store_settings SET website_url = 'https://ygenterprises.co.in' WHERE branch IN ('pos1', 'pos2');

COMMIT;
