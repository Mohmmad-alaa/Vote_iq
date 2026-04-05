CREATE TABLE IF NOT EXISTS public.agent_permissions (
    id SERIAL PRIMARY KEY,
    agent_id UUID NOT NULL REFERENCES public.agents(id) ON DELETE CASCADE,
    family_id INTEGER NULL REFERENCES public.families(id) ON DELETE CASCADE,
    sub_clan_id INTEGER NULL REFERENCES public.sub_clans(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS agent_permissions_scope_unique_idx
ON public.agent_permissions (agent_id, family_id, sub_clan_id);

ALTER TABLE public.agent_permissions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'agent_permissions'
          AND policyname = 'permissions_admin_all'
    ) THEN
        CREATE POLICY permissions_admin_all
        ON public.agent_permissions
        FOR ALL
        USING (
            EXISTS (
                SELECT 1
                FROM public.agents
                WHERE id = auth.uid() AND role = 'admin'
            )
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'agent_permissions'
          AND policyname = 'permissions_self_read'
    ) THEN
        CREATE POLICY permissions_self_read
        ON public.agent_permissions
        FOR SELECT
        USING (agent_id = auth.uid());
    END IF;
END
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.agent_permissions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.agent_permissions TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.agent_permissions_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.agent_permissions_id_seq TO service_role;

ALTER TABLE public.voters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voters ADD COLUMN IF NOT EXISTS refusal_reason TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'voters'
          AND policyname = 'voters_agent_access'
    ) THEN
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
                  AND (ap.family_id IS NULL OR ap.family_id = voters.family_id)
                  AND (ap.sub_clan_id IS NULL OR ap.sub_clan_id = voters.sub_clan_id)
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
                  AND (ap.family_id IS NULL OR ap.family_id = voters.family_id)
                  AND (ap.sub_clan_id IS NULL OR ap.sub_clan_id = voters.sub_clan_id)
            )
        );
    END IF;
END
$$;
