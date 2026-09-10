ALTER TABLE public.classes
ADD COLUMN IF NOT EXISTS class_code text;

CREATE UNIQUE INDEX IF NOT EXISTS classes_class_code_unique
ON public.classes (class_code)
WHERE class_code IS NOT NULL;

COMMENT ON COLUMN public.classes.class_code IS
'Stable internal course code, e.g. F120, F121, F320.';
