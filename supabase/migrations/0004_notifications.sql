-- 0004_notifications.sql
-- Milestone: adaa Phase 3 - Notifications & Activity Center
-- Description: Additive migration creating public.notifications table for in-app activity
-- notifications, recipient isolation, deduplication constraints, and RLS policies.
--
-- ROLLBACK STRATEGY:
-- To safely rollback this migration:
-- DROP TABLE IF EXISTS public.notifications CASCADE;
-- DELETE FROM public.schema_migrations WHERE version = '0005_notifications';

CREATE TABLE IF NOT EXISTS public.notifications (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    actor_id VARCHAR(36),
    actor_name VARCHAR(100),
    event_type VARCHAR(50) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    reference_id VARCHAR(36),
    reference_type VARCHAR(30),
    community_id VARCHAR(36),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance & recipient query indexes
CREATE INDEX IF NOT EXISTS ix_notifications_user_read_created 
    ON public.notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_notifications_user_created 
    ON public.notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_notifications_event_type 
    ON public.notifications (event_type);

CREATE INDEX IF NOT EXISTS ix_notifications_community_id 
    ON public.notifications (community_id);

-- Enforce duplicate event prevention at the database level:
-- Prevents duplicate notifications for the same event transition and entity.
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_dedup
    ON public.notifications (user_id, event_type, reference_id, reference_type)
    WHERE reference_id IS NOT NULL;

-- Enable Row Level Security (RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Scoped RLS Policies: Authenticated users can only read and update their own notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT TO authenticated
    USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
    ON public.notifications FOR UPDATE TO authenticated
    USING (auth.uid()::text = user_id)
    WITH CHECK (auth.uid()::text = user_id);

-- Grants
GRANT ALL ON public.notifications TO service_role, postgres;
GRANT SELECT, UPDATE (is_read) ON public.notifications TO authenticated;
