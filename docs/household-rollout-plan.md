# Household Rollout Plan

This rollout is designed to avoid data loss and keep old app versions working.

## Safety guarantees

- The database migration is additive only.
- No existing `voters` rows are deleted.
- No existing columns are dropped or renamed.
- No existing rows are rewritten automatically.
- The new app version now includes runtime fallback to the legacy schema if the household columns do not exist yet.
- Old app versions continue to work because the new columns are optional and do not change old field names.

## Recommended rollout order

1. Apply the schema migration:
   `supabase/migrations/20260424120000_add_household_sorting_fields.sql`
2. Run the read-only verification script:
   `supabase/debug/verify_household_schema.sql`
3. Deploy the new app version.
4. Start populating household data only after confirming the app is stable.
5. Keep old app clients active during the transition if needed; they will ignore the new columns.

## What the migration changes

The migration adds three optional fields to `public.voters`:

- `household_group`
- `household_role`
- `household_role_rank` as a generated column

It also adds one index for sorting performance:

- `idx_voters_household_sort`

## What the migration does not do

- It does not backfill family relationships automatically.
- It does not infer husband/wife/children from names.
- It does not change or normalize old voter records.
- It does not require immediate data cleanup.

## Deployment strategy

### Phase 1: Schema first

Apply the migration before relying on household sorting in production.

Reason:
- This keeps the new app compatible with the upgraded database.
- Because the app now has fallback logic, deploying the app before migration is also tolerated, but schema-first is still the safest production order.

### Phase 2: App rollout

Deploy the new app version after migration verification.

Behavior:
- If household fields are present, the app uses the new family-aware sorting and details UI.
- If household fields are missing in an environment, the app falls back to legacy behavior without crashing.

### Phase 3: Data population

Populate household data gradually, in small batches, after taking a database backup or snapshot.

Recommended approach:
- Start with a small pilot family set.
- Verify UI behavior for those records.
- Continue in batches.

Important:
- There is intentionally no automatic update query in this rollout, to avoid accidental data changes.

## Rollback posture

If the new UI or workflow needs to be paused:

- Keep the columns in place.
- Stop populating household fields.
- The old app remains unaffected.
- The new app can still operate using legacy fallback if needed.

This is safer than dropping columns or reverting schema under live usage.
