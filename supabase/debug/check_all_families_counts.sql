-- Debug helper: audit all families and voter counts across the whole database.
-- Run in Supabase SQL Editor.

-- 1) Raw count per family row exactly as stored in `families`.
select
  f.id as family_id,
  f.family_name,
  count(v.voter_symbol) as voters_count
from families f
left join voters v
  on v.family_id = f.id
group by f.id, f.family_name
order by voters_count desc, f.family_name, f.id;

-- 2) Aggregate counts by normalized family name.
-- This reveals families that are split across multiple rows due to spaces or duplicates.
with normalized_families as (
  select
    f.id,
    f.family_name,
    trim(regexp_replace(f.family_name, '\s+', ' ', 'g')) as normalized_family_name
  from families f
)
select
  nf.normalized_family_name,
  array_agg(nf.id order by nf.id) as family_ids,
  array_agg(nf.family_name order by nf.family_name, nf.id) as raw_family_names,
  count(distinct nf.id) as family_rows,
  count(v.voter_symbol) as voters_count
from normalized_families nf
left join voters v
  on v.family_id = nf.id
group by nf.normalized_family_name
order by voters_count desc, nf.normalized_family_name;

-- 3) Suspicious families only:
-- multiple family rows collapse to the same normalized name.
with normalized_families as (
  select
    f.id,
    f.family_name,
    trim(regexp_replace(f.family_name, '\s+', ' ', 'g')) as normalized_family_name
  from families f
)
select
  nf.normalized_family_name,
  array_agg(nf.id order by nf.id) as family_ids,
  array_agg(
    nf.family_name || ' [hex=' || encode(convert_to(nf.family_name, 'UTF8'), 'hex') || ']'
    order by nf.family_name, nf.id
  ) as raw_variants,
  count(distinct nf.id) as family_rows,
  count(v.voter_symbol) as voters_count
from normalized_families nf
left join voters v
  on v.family_id = nf.id
group by nf.normalized_family_name
having count(distinct nf.id) > 1
order by voters_count desc, nf.normalized_family_name;

-- 4) Families that have zero voters.
select
  f.id as family_id,
  f.family_name
from families f
left join voters v
  on v.family_id = f.id
group by f.id, f.family_name
having count(v.voter_symbol) = 0
order by f.family_name, f.id;

-- 5) Voters without a family assignment.
select count(*) as voters_with_null_family_id
from voters
where family_id is null;

-- 6) Optional summary numbers.
select
  (select count(*) from families) as total_family_rows,
  (
    select count(*)
    from (
      select trim(regexp_replace(family_name, '\s+', ' ', 'g')) as normalized_family_name
      from families
      group by 1
    ) x
  ) as total_normalized_family_names,
  (select count(*) from voters) as total_voters;
