-- 0001_initial_schema.sql
-- Milestone 1: Profiles, Automatic Sign-up Trigger, and Multi-Layer Anti-Escalation Defenses

-- 1. Create public profiles table linked to auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    student_email TEXT,
    is_student_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- STUDENT EMAIL VERIFICATION SECURITY CONTRACT & NOTICE:
-- 1. `student_email` is strictly self-reported user input. It NEVER independently
--    confers, implies, or grants verified student status.
-- 2. Verified status is represented SOLELY and EXCLUSIVELY by `is_student_verified = TRUE`.
-- 3. Application code, RLS policies, and community access gates must always check
--    `is_student_verified = TRUE`, NEVER `student_email IS NOT NULL`.
-- ==============================================================================

-- 2. Trigger function to automatically create a profile when a user signs up via Supabase Auth (Email or Google OAuth)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', '')
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = CASE WHEN profiles.full_name IS NULL OR profiles.full_name = '' THEN EXCLUDED.full_name ELSE profiles.full_name END,
        avatar_url = CASE WHEN profiles.avatar_url IS NULL OR profiles.avatar_url = '' THEN EXCLUDED.avatar_url ELSE profiles.avatar_url END,
        updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Secure execution privileges on handle_new_user
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role;

-- Bind trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Database Trigger for Column-Level Anti-Escalation Protection
-- Ensures that direct client requests via PostgREST / Supabase SDK cannot alter is_student_verified, id, email, or created_at
CREATE OR REPLACE FUNCTION public.protect_profile_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- If called by an authenticated end-user client (role = 'authenticated')
    IF auth.role() = 'authenticated' THEN
        -- Prevent changing is_student_verified directly
        IF NEW.is_student_verified IS DISTINCT FROM OLD.is_student_verified THEN
            RAISE EXCEPTION 'Cannot modify is_student_verified directly. Complete institutional student email verification first.';
        END IF;

        -- Prevent tampering with profile primary key
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Cannot alter profile id.';
        END IF;

        -- Prevent modifying primary account email directly (must be changed via Supabase Auth)
        IF NEW.email IS DISTINCT FROM OLD.email THEN
            RAISE EXCEPTION 'Cannot alter primary email directly. Update email through authentication service.';
        END IF;

        -- Prevent tampering with created_at timestamp
        IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Cannot alter created_at timestamp.';
        END IF;
    END IF;

    -- Update timestamp automatically on every successful modification
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Secure execution privileges on protect_profile_fields
REVOKE EXECUTE ON FUNCTION public.protect_profile_fields() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.protect_profile_fields() TO postgres, authenticated, service_role;

DROP TRIGGER IF EXISTS protect_profile_fields_trigger ON public.profiles;
CREATE TRIGGER protect_profile_fields_trigger
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_profile_fields();

-- 4. Controlled Server-Side Verification Mechanism
-- Trusted server backend (e.g., FastAPI backend or Supabase Edge Function) invokes this RPC
-- with the service_role key after verifying an institutional OTP or magic link.
CREATE OR REPLACE FUNCTION public.verify_student_status(
    target_user_id UUID,
    verified_student_email TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Reject calls from untrusted authenticated client sessions
    IF auth.role() = 'authenticated' THEN
        RAISE EXCEPTION 'Permission denied. Student verification can only be performed by trusted backend services.';
    END IF;

    IF verified_student_email IS NULL OR trim(verified_student_email) = '' THEN
        RAISE EXCEPTION 'Verified student email cannot be empty.';
    END IF;

    UPDATE public.profiles
    SET
        student_email = trim(verified_student_email),
        is_student_verified = TRUE,
        updated_at = NOW()
    WHERE id = target_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile for user % not found.', target_user_id;
    END IF;
END;
$$;

-- Strictly limit execution of verify_student_status to service_role and postgres
REVOKE EXECUTE ON FUNCTION public.verify_student_status(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_student_status(UUID, TEXT) TO service_role, postgres;

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
-- Readable by all authenticated users for community displays
DROP POLICY IF EXISTS "Public profiles are readable by authenticated users" ON public.profiles;
CREATE POLICY "Public profiles are readable by authenticated users"
    ON public.profiles FOR SELECT TO authenticated
    USING (true);

-- Users can update only their own profile details
DROP POLICY IF EXISTS "Users can update their own profile details" ON public.profiles;
CREATE POLICY "Users can update their own profile details"
    ON public.profiles FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 7. Column-level privilege restriction for authenticated role (Defense-in-depth Layer)
REVOKE UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE (full_name, avatar_url, bio, student_email) ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO authenticated;
