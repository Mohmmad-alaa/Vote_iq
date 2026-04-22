-- Add is_manager column to agent_permissions table
ALTER TABLE "public"."agent_permissions" 
ADD COLUMN IF NOT EXISTS "is_manager" BOOLEAN NOT NULL DEFAULT false;

-- Create or update the RPC to support the new column
CREATE OR REPLACE FUNCTION public.add_agent_permission(
  agent_id UUID,
  family_id INTEGER DEFAULT NULL,
  sub_clan_id INTEGER DEFAULT NULL,
  is_manager BOOLEAN DEFAULT false,
  access_token TEXT DEFAULT NULL
)
RETURNS public.agent_permissions
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_permission public.agent_permissions;
BEGIN
  INSERT INTO public.agent_permissions (agent_id, family_id, sub_clan_id, is_manager)
  VALUES (agent_id, family_id, sub_clan_id, is_manager)
  RETURNING * INTO new_permission;
  
  RETURN new_permission;
END;
$$;
