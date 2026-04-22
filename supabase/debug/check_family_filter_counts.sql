-- Debug helper: verify whether family filtering is correct in the database.
-- Run this file in Supabase SQL Editor, then replace the target value below.

with target as (
  select 'هرشة'::text as family_name
),
normalized_target as (
  select trim(regexp_replace(family_name, '\s+', ' ', 'g')) as family_name
  from target
)

-- 1) Exact family rows that match the requested visible name.
select
  f.id,
  f.family_name,
  length(f.family_name) as raw_length,
  length(trim(f.family_name)) as trimmed_length,
  encode(convert_to(f.family_name, 'UTF8'), 'hex') as utf8_hex
from families f
join target t
  on f.family_name = t.family_name
order by f.id;

-- 2) Near/normalized matches. This catches hidden spaces and similar variants.
with target as (
  select 'هرشة'::text as family_name
),
normalized_target as (
  select trim(regexp_replace(family_name, '\s+', ' ', 'g')) as family_name
  from target
)
select
  f.id,
  f.family_name,
  trim(regexp_replace(f.family_name, '\s+', ' ', 'g')) as normalized_name,
  similarity(
    trim(regexp_replace(f.family_name, '\s+', ' ', 'g')),
    (select family_name from normalized_target)
  ) as similarity_score,
  encode(convert_to(f.family_name, 'UTF8'), 'hex') as utf8_hex
from families f
where trim(regexp_replace(f.family_name, '\s+', ' ', 'g')) =
        (select family_name from normalized_target)
   or similarity(
        trim(regexp_replace(f.family_name, '\s+', ' ', 'g')),
        (select family_name from normalized_target)
      ) >= 0.6
order by similarity_score desc, f.family_name;

-- 3) Count voters per exact matching family row.
with target as (
  select 'هرشة'::text as family_name
)
select
  f.id as family_id,
  f.family_name,
  count(v.voter_symbol) as voters_count
from families f
left join voters v
  on v.family_id = f.id
join target t
  on f.family_name = t.family_name
group by f.id, f.family_name
order by voters_count desc, f.id;

-- 4) Count voters across all normalized family-name variants together.
with target as (
  select 'هرشة'::text as family_name
),
normalized_target as (
  select trim(regexp_replace(family_name, '\s+', ' ', 'g')) as family_name
  from target
)
select
  trim(regexp_replace(f.family_name, '\s+', ' ', 'g')) as normalized_family_name,
  count(v.voter_symbol) as voters_count
from voters v
join families f
  on f.id = v.family_id
where trim(regexp_replace(f.family_name, '\s+', ' ', 'g')) =
      (select family_name from normalized_target)
group by normalized_family_name;

-- 5) Sanity check: how many voters have no family assigned at all.
select count(*) as voters_with_null_family_id
from voters
where family_id is null;

-- 6) Optional: inspect a small sample of voters for the matched family variants.
with target as (
  select 'هرشة'::text as family_name
),
normalized_target as (
  select trim(regexp_replace(family_name, '\s+', ' ', 'g')) as family_name
  from target
)
select
  v.voter_symbol,
  v.first_name,
  v.father_name,
  v.grandfather_name,
  v.family_id,
  f.family_name
from voters v
join families f
  on f.id = v.family_id
where trim(regexp_replace(f.family_name, '\s+', ' ', 'g')) =
      (select family_name from normalized_target)
order by v.voter_symbol
limit 50;
