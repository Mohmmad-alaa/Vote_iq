CREATE INDEX IF NOT EXISTS idx_voters_family_id
ON public.voters (family_id);

CREATE INDEX IF NOT EXISTS idx_voters_sub_clan_id
ON public.voters (sub_clan_id);

CREATE INDEX IF NOT EXISTS idx_voters_center_id
ON public.voters (center_id);

CREATE INDEX IF NOT EXISTS idx_voters_status
ON public.voters (status);

CREATE INDEX IF NOT EXISTS idx_voters_updated_at
ON public.voters (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_voters_status_list_id
ON public.voters (status, list_id)
WHERE list_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_voter_candidates_voter_candidate
ON public.voter_candidates (voter_symbol, candidate_id);

CREATE OR REPLACE FUNCTION public.get_list_and_candidate_votes()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH visible_voters AS (
    SELECT voter_symbol, list_id
    FROM public.voters
    WHERE list_id IS NOT NULL
),
list_counts AS (
    SELECT
        list_id,
        COUNT(*)::INT AS vote_count
    FROM visible_voters
    GROUP BY list_id
),
candidate_counts AS (
    SELECT
        vc.candidate_id,
        COUNT(*)::INT AS vote_count
    FROM visible_voters vv
    JOIN public.voter_candidates vc
      ON vc.voter_symbol = vv.voter_symbol
    GROUP BY vc.candidate_id
)
SELECT jsonb_build_object(
    'listVotes',
    COALESCE(
        (SELECT jsonb_object_agg(list_id::TEXT, vote_count) FROM list_counts),
        '{}'::jsonb
    ),
    'candidateVotes',
    COALESCE(
        (
            SELECT jsonb_object_agg(candidate_id::TEXT, vote_count)
            FROM candidate_counts
        ),
        '{}'::jsonb
    )
);
$$;

GRANT EXECUTE ON FUNCTION public.get_list_and_candidate_votes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_list_and_candidate_votes() TO service_role;
