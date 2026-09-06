-- Generate actual class session rows from a class schedule.
-- Uses Taiwan local time explicitly so production server timezone does not matter.

CREATE OR REPLACE FUNCTION public.rpc_generate_class_sessions(
  p_class_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class public.classes%ROWTYPE;
  v_term public.terms%ROWTYPE;
  v_date date;
  v_count integer := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin_required';
  END IF;

  SELECT *
  INTO v_class
  FROM public.classes
  WHERE id = p_class_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'class_not_found';
  END IF;

  SELECT *
  INTO v_term
  FROM public.terms
  WHERE id = v_class.term_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'term_not_found';
  END IF;

  FOR v_date IN
    SELECT d::date
    FROM generate_series(
      v_term.start_date::timestamp,
      v_term.end_date::timestamp,
      interval '1 day'
    ) AS d
    WHERE EXTRACT(DOW FROM d)::integer = ANY(v_class.weekdays)
    ORDER BY d
  LOOP
    INSERT INTO public.class_sessions (
      class_id,
      session_date,
      start_at,
      end_at,
      status,
      base_makeup_capacity
    )
    VALUES (
      v_class.id,
      v_date,
      (v_date + v_class.start_time) AT TIME ZONE 'Asia/Taipei',
      (v_date + v_class.end_time) AT TIME ZONE 'Asia/Taipei',
      'scheduled',
      v_class.default_base_makeup_capacity
    )
    ON CONFLICT (class_id, session_date)
    DO UPDATE SET
      start_at = EXCLUDED.start_at,
      end_at = EXCLUDED.end_at,
      base_makeup_capacity = EXCLUDED.base_makeup_capacity;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_generate_class_sessions(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_generate_class_sessions(uuid) TO authenticated;
