-- 0002_item_requests.sql
-- Milestone: Community Borrowing, Public Profiles & Request Tracking
-- Description: Additive migration creating item_requests table for garment-level borrowing coordination.
--
-- ROLLBACK STRATEGY:
-- To safely rollback this migration:
-- DROP TABLE IF EXISTS public.item_requests CASCADE;
-- DELETE FROM public.schema_migrations WHERE version = '0004_item_requests';

CREATE TABLE IF NOT EXISTS public.item_requests (
    id VARCHAR(36) PRIMARY KEY,
    listing_id VARCHAR(36) NOT NULL REFERENCES public.community_listings(id) ON DELETE CASCADE,
    wardrobe_item_id VARCHAR(36) NOT NULL REFERENCES public.wardrobe_items(id) ON DELETE CASCADE,
    community_id VARCHAR(36) NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    requester_id VARCHAR(36) NOT NULL,
    owner_id VARCHAR(36) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    message TEXT,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    responded_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance & lookups indexes
CREATE INDEX IF NOT EXISTS ix_item_requests_owner_status ON public.item_requests (owner_id, status);
CREATE INDEX IF NOT EXISTS ix_item_requests_requester_status ON public.item_requests (requester_id, status);
CREATE INDEX IF NOT EXISTS ix_item_requests_listing_status ON public.item_requests (listing_id, status);
CREATE INDEX IF NOT EXISTS ix_item_requests_community_id ON public.item_requests (community_id);

-- Enforce duplicate pending request prevention at the database level:
-- A user cannot submit multiple concurrent pending requests for the same listing.
CREATE UNIQUE INDEX IF NOT EXISTS uq_item_requests_pending
    ON public.item_requests (listing_id, requester_id)
    WHERE status = 'pending';
