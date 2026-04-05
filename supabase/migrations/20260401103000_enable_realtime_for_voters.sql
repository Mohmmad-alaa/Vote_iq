ALTER TABLE public.voters REPLICA IDENTITY FULL;
ALTER TABLE public.agent_permissions REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = 'voters'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.voters;
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = 'agent_permissions'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.agent_permissions;
        END IF;
    END IF;
END
$$;
