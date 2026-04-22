-- Safely add ON DELETE SET NULL to updated_by foreign key in voters table
DO $$
BEGIN
    -- If there's an existing foreign key for updated_by
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_name = 'voters'
          AND kcu.column_name = 'updated_by'
    ) THEN
        -- We don't know the exact name of the constraint, so we dynamically drop it
        -- Actually, a simple ALTER TABLE DROP CONSTRAINT IF EXISTS voters_updated_by_fkey might work
        -- But this is safer: dynamically find and drop the constraint
        DECLARE
            fkey_name text;
        BEGIN
            SELECT tc.constraint_name INTO fkey_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_name = 'voters'
              AND kcu.column_name = 'updated_by'
            LIMIT 1;

            EXECUTE 'ALTER TABLE public.voters DROP CONSTRAINT ' || quote_ident(fkey_name);
        END;
    END IF;

    -- Add the foreign key with ON DELETE SET NULL
    -- If the column updated_by exists
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns 
        WHERE table_name = 'voters' AND column_name = 'updated_by'
    ) THEN
        ALTER TABLE public.voters
        ADD CONSTRAINT voters_updated_by_fkey
        FOREIGN KEY (updated_by) REFERENCES public.agents(id) ON DELETE SET NULL;
    END IF;
END $$;
