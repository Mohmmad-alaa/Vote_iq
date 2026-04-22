DROP POLICY IF EXISTS voters_agent_access ON public.voters;

CREATE POLICY voters_agent_access
ON public.voters
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.agents a
    WHERE a.id = auth.uid()
      AND a.role = 'agent'
      AND a.is_active = TRUE
  )
  AND EXISTS (
    SELECT 1
    FROM public.agent_permissions ap
    WHERE ap.agent_id = auth.uid()
      AND (
        ap.family_id IS NULL
        OR (
          ap.family_id = voters.family_id
          AND (
            ap.sub_clan_id IS NULL
            OR ap.sub_clan_id = voters.sub_clan_id
            OR (
              ap.is_manager = TRUE
              AND ap.sub_clan_id IS NOT NULL
              AND voters.sub_clan_id IS NULL
            )
          )
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.agents a
    WHERE a.id = auth.uid()
      AND a.role = 'agent'
      AND a.is_active = TRUE
  )
  AND EXISTS (
    SELECT 1
    FROM public.agent_permissions ap
    WHERE ap.agent_id = auth.uid()
      AND (
        ap.family_id IS NULL
        OR (
          ap.family_id = voters.family_id
          AND (
            ap.sub_clan_id IS NULL
            OR ap.sub_clan_id = voters.sub_clan_id
            OR (
              ap.is_manager = TRUE
              AND ap.sub_clan_id IS NOT NULL
              AND voters.sub_clan_id IS NULL
            )
          )
        )
      )
  )
);
