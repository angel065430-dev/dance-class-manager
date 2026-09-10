-- Additive name feature. Existing profiles and identity IDs remain unchanged.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS line_display_name text;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND conname = 'profiles_line_display_name_length'
  ) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_line_display_name_length
      CHECK (line_display_name IS NULL OR char_length(line_display_name) <= 100) NOT VALID;
  END IF;
END $$;
ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_line_display_name_length;
COMMENT ON COLUMN public.profiles.line_display_name IS
  'Student-supplied LINE display name, not a LINE account identifier.';
