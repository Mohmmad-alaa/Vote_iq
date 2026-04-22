-- ============================================================
--  قاعدة بيانات تطبيق متابعة الناخبين — Schema النهائي الموحد
--  منصة: Supabase (PostgreSQL)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. مراكز الاقتراع
CREATE TABLE voting_centers (
    id          SERIAL PRIMARY KEY,
    center_name TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. العائلات الرئيسية
CREATE TABLE families (
    id          SERIAL PRIMARY KEY,
    family_name TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. الفروع العائلية
CREATE TABLE sub_clans (
    id          SERIAL PRIMARY KEY,
    family_id   INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    sub_name    TEXT    NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (family_id, sub_name)
);

-- 4. الوكلاء
CREATE TABLE agents (
    id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name   TEXT    NOT NULL,
    username    TEXT    NOT NULL UNIQUE,
    role        TEXT    NOT NULL DEFAULT 'agent'
                        CHECK (role IN ('admin', 'agent')),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 5. صلاحيات الوكلاء
CREATE TABLE agent_permissions (
    id          SERIAL  PRIMARY KEY,
    agent_id    UUID    NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    family_id   INTEGER REFERENCES families(id)  ON DELETE CASCADE,
    sub_clan_id INTEGER REFERENCES sub_clans(id) ON DELETE CASCADE,
    UNIQUE (agent_id, family_id, sub_clan_id)
);

-- 6. الناخبون
CREATE TABLE voters (
    voter_symbol      TEXT    PRIMARY KEY,
    first_name        TEXT,
    father_name       TEXT,
    grandfather_name  TEXT,
    family_id         INTEGER REFERENCES families(id),
    sub_clan_id       INTEGER REFERENCES sub_clans(id),
    center_id         INTEGER REFERENCES voting_centers(id),
    status            TEXT    NOT NULL DEFAULT 'لم يصوت'
                              CHECK (status IN ('لم يصوت', 'تم التصويت', 'رفض')),
    refusal_reason    TEXT,
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_by        UUID REFERENCES agents(id),
    search_text       TEXT GENERATED ALWAYS AS (
                          COALESCE(voter_symbol, '') || ' ' ||
                          COALESCE(first_name, '') || ' ' ||
                          COALESCE(father_name, '') || ' ' ||
                          COALESCE(grandfather_name, '')
                      ) STORED
);

CREATE INDEX voters_search_idx  ON voters USING GIN (search_text gin_trgm_ops);
CREATE INDEX voters_family_idx  ON voters (family_id);
CREATE INDEX voters_subclan_idx ON voters (sub_clan_id);
CREATE INDEX voters_center_idx  ON voters (center_id);
CREATE INDEX voters_status_idx  ON voters (status);

-- 7. Trigger
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER voters_updated_at
    BEFORE UPDATE ON voters
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- 8. RLS
ALTER TABLE voters          ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents          ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE families        ENABLE ROW LEVEL SECURITY;
ALTER TABLE sub_clans       ENABLE ROW LEVEL SECURITY;
ALTER TABLE voting_centers  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "voters_admin_all" ON voters
    FOR ALL USING (
        EXISTS (SELECT 1 FROM agents WHERE id = auth.uid() AND role = 'admin' AND is_active = TRUE)
    );

CREATE POLICY "voters_agent_access" ON voters
    FOR ALL USING (
        EXISTS (SELECT 1 FROM agents a WHERE a.id = auth.uid() AND a.role = 'agent' AND a.is_active = TRUE)
        AND EXISTS (
            SELECT 1 FROM agent_permissions ap
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

CREATE POLICY "voters_agent_no_delete" ON voters
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM agents WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "agents_self_read" ON agents FOR SELECT USING (id = auth.uid());
CREATE POLICY "agents_admin_all" ON agents FOR ALL USING (
    EXISTS (SELECT 1 FROM agents WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "families_read_all" ON families FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "families_admin_write" ON families FOR ALL USING (
    EXISTS (SELECT 1 FROM agents WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "sub_clans_read_all" ON sub_clans FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "sub_clans_admin_write" ON sub_clans FOR ALL USING (
    EXISTS (SELECT 1 FROM agents WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "centers_read_all" ON voting_centers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "centers_admin_write" ON voting_centers FOR ALL USING (
    EXISTS (SELECT 1 FROM agents WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "permissions_admin_all" ON agent_permissions FOR ALL USING (
    EXISTS (SELECT 1 FROM agents WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "permissions_self_read" ON agent_permissions FOR SELECT USING (agent_id = auth.uid());

-- 9. Real-time
ALTER PUBLICATION supabase_realtime ADD TABLE voters;

-- 10. بيانات أولية
INSERT INTO voting_centers (center_name) VALUES
    ('مركز الشهداء'), ('مركز الأمل'), ('مركز النور'), ('مركز قفين الغربي'), ('مركز الوسطى');

INSERT INTO families (family_name) VALUES ('هرشة'), ('خصيب'), ('عمار');

INSERT INTO sub_clans (family_id, sub_name) VALUES
    (1, 'زبداوي'), (1, 'نافلة'), (1, 'أبو ربيع'), (1, 'القاضي'), (1, 'المطارنة'),
    (2, 'الشمالي'), (2, 'الجنوبي'), (2, 'أبو نمر'),
    (3, 'الكبير'), (3, 'الصغير');
