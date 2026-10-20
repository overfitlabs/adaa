-- 0005_saved_outfits.sql
-- Milestone: adaa Phase 4 - AI Stylist & Saved Outfits
-- Description: Additive migration ensuring public.saved_outfits table exists with proper
-- recipient isolation, user indexes, and Row-Level Security (RLS) policies.
--
-- ROLLBACK STRATEGY:
-- To safely rollback this migration:
-- DROP TABLE IF EXISTS public.saved_outfits CASCADE;
-- DELETE FROM public.schema_migrations WHERE version = '0006_saved_outfits_security';

CREATE TABLE IF NOT EXISTS public.saved_outfits (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    occasion VARCHAR(60),
    notes TEXT,
    image_path VARCHAR(255),
    storage_provider VARCHAR(30) NOT NULL DEFAULT 'local',
    cloudinary_public_id VARCHAR(255),
    item_ids_json TEXT NOT NULL DEFAULT '[]',
    inspiration_analysis_id VARCHAR(36),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance & user lookup indexes
CREATE INDEX IF NOT EXISTS ix_saved_outfits_user_id 
    ON public.saved_outfits (user_id);

CREATE INDEX IF NOT EXISTS ix_saved_outfits_user_created 
    ON public.saved_outfits (user_id, created_at DESC);

-- Enable Row-Level Security (RLS)
ALTER TABLE public.saved_outfits ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Authenticated users can only read, create, update, and delete their own saved outfits
DROP POLICY IF EXISTS "saved_outfits_select_policy" ON public.saved_outfits;
CREATE POLICY "saved_outfits_select_policy"
    ON public.saved_outfits FOR SELECT TO authenticated
    USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "saved_outfits_insert_policy" ON public.saved_outfits;
CREATE POLICY "saved_outfits_insert_policy"
    ON public.saved_outfits FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "saved_outfits_update_policy" ON public.saved_outfits;
CREATE POLICY "saved_outfits_update_policy"
    ON public.saved_outfits FOR UPDATE TO authenticated
    USING (user_id = auth.uid()::text)
    WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "saved_outfits_delete_policy" ON public.saved_outfits;
CREATE POLICY "saved_outfits_delete_policy"
    ON public.saved_outfits FOR DELETE TO authenticated
    USING (user_id = auth.uid()::text);
