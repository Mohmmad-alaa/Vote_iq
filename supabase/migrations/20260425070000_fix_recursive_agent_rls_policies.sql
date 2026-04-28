CREATE OR REPLACE FUNCTION public.auth_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.agents
    WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = TRUE
  );
$$;

CREATE OR REPLACE FUNCTION public.auth_is_active_agent()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.agents
    WHERE id = auth.uid()
      AND role = 'agent'
      AND is_active = TRUE
  );
$$;

CREATE OR REPLACE FUNCTION public.auth_created_agent(target_agent_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.agents
    WHERE id = target_agent_id
      AND created_by = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.auth_is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.auth_is_active_agent() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.auth_created_agent(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.auth_is_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.auth_is_active_agent() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.auth_created_agent(UUID) TO authenticated, service_role;

DROP POLICY IF EXISTS "voters_admin_all" ON public.voters;
CREATE POLICY "voters_admin_all" ON public.voters
  FOR ALL
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

DROP POLICY IF EXISTS "voters_agent_access" ON public.voters;
CREATE POLICY "voters_agent_access" ON public.voters
  FOR ALL
  USING (
    public.auth_is_active_agent()
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
            )
          )
          OR (
            ap.is_manager = TRUE
            AND voters.sub_clan_id IS NULL
          )
        )
    )
  )
  WITH CHECK (
    public.auth_is_active_agent()
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
            )
          )
          OR (
            ap.is_manager = TRUE
            AND voters.sub_clan_id IS NULL
          )
        )
    )
  );

DROP POLICY IF EXISTS "voters_agent_no_delete" ON public.voters;
CREATE POLICY "voters_agent_no_delete" ON public.voters
  FOR DELETE
  USING (public.auth_is_admin());

DROP POLICY IF EXISTS "agents_admin_all" ON public.agents;
CREATE POLICY "agents_admin_all" ON public.agents
  FOR ALL
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

DROP POLICY IF EXISTS "agents_created_by_read" ON public.agents;
CREATE POLICY "agents_created_by_read" ON public.agents
  FOR SELECT
  USING (public.auth_created_agent(id));

DROP POLICY IF EXISTS "families_admin_write" ON public.families;
CREATE POLICY "families_admin_write" ON public.families
  FOR ALL
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

DROP POLICY IF EXISTS "sub_clans_admin_write" ON public.sub_clans;
CREATE POLICY "sub_clans_admin_write" ON public.sub_clans
  FOR ALL
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

DROP POLICY IF EXISTS "centers_admin_write" ON public.voting_centers;
CREATE POLICY "centers_admin_write" ON public.voting_centers
  FOR ALL
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

DROP POLICY IF EXISTS "permissions_admin_all" ON public.agent_permissions;
CREATE POLICY "permissions_admin_all" ON public.agent_permissions
  FOR ALL
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

DROP POLICY IF EXISTS "permissions_created_by_read" ON public.agent_permissions;
CREATE POLICY "permissions_created_by_read" ON public.agent_permissions
  FOR SELECT
  USING (public.auth_created_agent(agent_id));
