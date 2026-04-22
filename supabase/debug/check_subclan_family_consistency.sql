-- Debug helper: verify whether sub-clans affect family results indirectly
-- by having voters whose family_id does not match the family of their sub_clan_id.
-- Run in Supabase SQL Editor.

-- 1) Overall mismatch summary.
select
  count(*) filter (where v.sub_clan_id is not null) as voters_with_sub_clan,
  count(*) filter (
    where v.sub_clan_id is not null
      and v.family_id is null
  ) as voters_with_sub_clan_and_null_family,
  count(*) filter (
    where v.sub_clan_id is not null
      and sc.family_id is distinct from v.family_id
  ) as voters_with_family_subclan_mismatch
from voters v
left join sub_clans sc
  on sc.id = v.sub_clan_id;

-- 2) Detailed mismatched voters.
select
  v.voter_symbol,
  v.first_name,
  v.father_name,
  v.grandfather_name,
  v.family_id as voter_family_id,
  vf.family_name as voter_family_name,
  v.sub_clan_id,
  sc.sub_name as sub_clan_name,
  sc.family_id as sub_clan_family_id,
  sf.family_name as sub_clan_family_name
from voters v
join sub_clans sc
  on sc.id = v.sub_clan_id
left join families vf
  on vf.id = v.family_id
left join families sf
  on sf.id = sc.family_id
where sc.family_id is distinct from v.family_id
order by sf.family_name, sc.sub_name, v.voter_symbol;

-- 3) Count mismatches grouped by the family implied by the sub-clan.
select
  sf.family_name as sub_clan_family_name,
  sc.sub_name as sub_clan_name,
  count(*) as mismatched_voters_count
from voters v
join sub_clans sc
  on sc.id = v.sub_clan_id
left join families sf
  on sf.id = sc.family_id
where sc.family_id is distinct from v.family_id
group by sf.family_name, sc.sub_name
order by mismatched_voters_count desc, sf.family_name, sc.sub_name;

-- 4) Compare counts by direct family_id vs family inferred from sub-clan.
with by_family_id as (
  select
    f.id as family_id,
    f.family_name,
    count(v.voter_symbol) as count_by_family_id
  from families f
  left join voters v
    on v.family_id = f.id
  group by f.id, f.family_name
),
by_sub_clan_family as (
  select
    f.id as family_id,
    f.family_name,
    count(v.voter_symbol) as count_by_sub_clan_family
  from families f
  left join sub_clans sc
    on sc.family_id = f.id
  left join voters v
    on v.sub_clan_id = sc.id
  group by f.id, f.family_name
)
select
  bf.family_id,
  bf.family_name,
  bf.count_by_family_id,
  bsc.count_by_sub_clan_family,
  (bsc.count_by_sub_clan_family - bf.count_by_family_id) as delta
from by_family_id bf
join by_sub_clan_family bsc
  on bsc.family_id = bf.family_id
where bf.count_by_family_id <> bsc.count_by_sub_clan_family
order by abs(bsc.count_by_sub_clan_family - bf.count_by_family_id) desc,
         bf.family_name;
