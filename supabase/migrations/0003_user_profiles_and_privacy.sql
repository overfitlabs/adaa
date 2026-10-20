-- 0003_user_profiles_and_privacy.sql
-- Milestone: Complete User Profiles & Field-Level Privacy Settings
-- Description: Additive migration extending public.profiles with sizing, fit preferences,
-- and field-level visibility controls for community interactions.
--
-- ROLLBACK STRATEGY:
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS phone_number;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS birth_date;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS age;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS tops_size;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS bottoms_size;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS shoe_size;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS preferred_fit;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS preferred_styles;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS show_profile_photo;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS show_bio;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS show_age;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS show_phone;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS show_email;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS show_fit_preferences;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS show_preferred_styles;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS phone_number TEXT,
    ADD COLUMN IF NOT EXISTS birth_date DATE,
    ADD COLUMN IF NOT EXISTS age INTEGER,
    ADD COLUMN IF NOT EXISTS tops_size VARCHAR(30),
    ADD COLUMN IF NOT EXISTS bottoms_size VARCHAR(30),
    ADD COLUMN IF NOT EXISTS shoe_size VARCHAR(30),
    ADD COLUMN IF NOT EXISTS preferred_fit VARCHAR(30),
    ADD COLUMN IF NOT EXISTS preferred_styles TEXT DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS show_profile_photo BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS show_bio BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS show_age BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS show_phone BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS show_email BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS show_fit_preferences BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS show_preferred_styles BOOLEAN NOT NULL DEFAULT TRUE;

-- Performance index for community profile lookups
CREATE INDEX IF NOT EXISTS ix_profiles_full_name ON public.profiles (full_name);
