-- Safe verification script for the household sorting rollout.
-- This file is read-only. It does not modify data.

-- 1) Confirm the new columns exist on public.voters.
select
  column_name,
  data_type,
  is_nullable,
  generation_expression
from information_schema.columns
where table_schema = 'public'
  and table_name = 'voters'
  and column_name in ('household_group', 'household_role', 'household_role_rank')
order by column_name;

-- 2) Confirm the supporting index exists.
select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'voters'
  and indexname = 'idx_voters_household_sort';

-- 3) Count current usage of the new fields without changing any records.
select
  count(*) as total_voters,
  count(*) filter (where household_group is not null) as voters_with_household_group,
  count(*) filter (where household_role is not null) as voters_with_household_role
from public.voters;

-- 4) Breakdown by household role, if data has started to be populated.
select
  household_role,
  count(*) as total_rows
from public.voters
group by household_role
order by household_role nulls first;
