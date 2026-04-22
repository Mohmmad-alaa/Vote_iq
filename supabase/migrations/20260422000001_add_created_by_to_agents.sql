ALTER TABLE agents ADD COLUMN created_by UUID REFERENCES agents(id) ON DELETE SET NULL;

CREATE POLICY "agents_created_by_read" ON agents FOR SELECT USING (created_by = auth.uid());

CREATE POLICY "permissions_created_by_read" ON agent_permissions FOR SELECT USING (
    agent_id IN (SELECT id FROM agents WHERE created_by = auth.uid())
);
