CREATE OR REPLACE FUNCTION public.replace_voter_candidates(
    p_voter_symbol VARCHAR,
    p_candidate_ids BIGINT[]
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    candidate_id BIGINT;
    vote_position INTEGER := 1;
    normalized_candidate_ids BIGINT[] := COALESCE(
        p_candidate_ids,
        ARRAY[]::BIGINT[]
    );
BEGIN
    IF cardinality(normalized_candidate_ids) > 5 THEN
        RAISE EXCEPTION 'At most 5 candidates can be saved for a voter';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM unnest(normalized_candidate_ids) AS selected_candidate(candidate_id)
        GROUP BY candidate_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate candidate ids are not allowed';
    END IF;

    DELETE FROM public.voter_candidates
    WHERE voter_symbol = p_voter_symbol;

    FOREACH candidate_id IN ARRAY normalized_candidate_ids
    LOOP
        INSERT INTO public.voter_candidates (
            voter_symbol,
            candidate_id,
            vote_order
        )
        VALUES (
            p_voter_symbol,
            candidate_id,
            vote_position
        );

        vote_position := vote_position + 1;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.replace_voter_candidates(VARCHAR, BIGINT[])
TO authenticated;

GRANT EXECUTE ON FUNCTION public.replace_voter_candidates(VARCHAR, BIGINT[])
TO service_role;
