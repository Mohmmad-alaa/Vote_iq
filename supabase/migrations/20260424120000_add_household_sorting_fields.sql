-- Safe additive migration for household-aware sorting.
-- This migration does NOT delete rows, rewrite existing voter data,
-- or add NOT NULL requirements to existing records.
-- Old app versions continue to work because the added columns are optional.

ALTER TABLE public.voters
ADD COLUMN IF NOT EXISTS household_group TEXT,
ADD COLUMN IF NOT EXISTS household_role TEXT;

ALTER TABLE public.voters
DROP CONSTRAINT IF EXISTS voters_household_role_check;

ALTER TABLE public.voters
ADD CONSTRAINT voters_household_role_check
CHECK (
  household_role IS NULL OR household_role IN ('husband', 'wife', 'child', 'other')
);

ALTER TABLE public.voters
ADD COLUMN IF NOT EXISTS household_role_rank SMALLINT
GENERATED ALWAYS AS (
  CASE household_role
    WHEN 'husband' THEN 0
    WHEN 'wife' THEN 1
    WHEN 'child' THEN 2
    ELSE 3
  END
) STORED;

CREATE INDEX IF NOT EXISTS idx_voters_household_sort
ON public.voters (family_id, household_group, household_role_rank, voter_symbol);
