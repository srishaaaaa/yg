# YG Enterprises Supabase setup

Apply the migrations in filename order to the dedicated YG Enterprises Supabase project (or paste `RUN_ALL_MIGRATIONS.sql` in one go via the SQL Editor).

1. Run `20260716_0001_purple_boutique_schema.sql` (base schema — filename kept for history, content is YG Enterprises' schema).
2. Run `20260716_0002_purple_boutique_catalog.sql` (filename kept for history).
3. Continue through the remaining files in `supabase/migrations/` in filename order.
4. Create the owner account in Supabase Authentication and set its `role` metadata to `admin` if customer login is enabled.

The schema migration is idempotent. Invoice numbers use the format `PB-YYYY-000001` (POS 1) / a disjoint numeric range (POS 2) and are allocated under a locked database sequence per branch to prevent duplicates during concurrent billing.
