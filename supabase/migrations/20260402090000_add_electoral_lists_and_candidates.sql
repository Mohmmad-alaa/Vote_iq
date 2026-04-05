CREATE TABLE IF NOT EXISTS public.electoral_lists (
    id SERIAL PRIMARY KEY,
    list_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.candidates (
    id SERIAL PRIMARY KEY,
    candidate_name TEXT NOT NULL,
    list_id INTEGER NULL REFERENCES public.electoral_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.voters
    ADD COLUMN IF NOT EXISTS list_id INTEGER NULL REFERENCES public.electoral_lists(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS candidate_id INTEGER NULL REFERENCES public.candidates(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS candidates_list_id_idx
ON public.candidates (list_id);

CREATE INDEX IF NOT EXISTS voters_list_id_idx
ON public.voters (list_id);

CREATE INDEX IF NOT EXISTS voters_candidate_id_idx
ON public.voters (candidate_id);

GRANT SELECT ON TABLE public.electoral_lists TO authenticated;
GRANT SELECT ON TABLE public.electoral_lists TO service_role;
GRANT SELECT ON TABLE public.candidates TO authenticated;
GRANT SELECT ON TABLE public.candidates TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.electoral_lists_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.electoral_lists_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.candidates_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.candidates_id_seq TO service_role;
