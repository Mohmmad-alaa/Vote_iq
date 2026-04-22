-- Add the is_manager column to agent_permissions
ALTER TABLE "public"."agent_permissions"
ADD COLUMN IF NOT EXISTS "is_manager" BOOLEAN NOT NULL DEFAULT false;

-- If you have a stored procedure / RPC to add agent permissions (e.g. add-agent-permission edge function),
-- ensure you update it if needed. However, since the database now has a default, standard inserts via the API
-- will work fine. 
