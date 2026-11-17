CREATE OR REPLACE FUNCTION public.cf_sync_tick_limit(_limit int)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT user_id FROM public.codeforces_accounts WHERE status_request_id IS NOT NULL LOOP
    PERFORM public.cf_process_sync(r.user_id);
  END LOOP;
  FOR r IN
    SELECT a.user_id FROM public.codeforces_accounts a
    JOIN public.profiles p ON p.id = a.user_id AND p.is_active
    WHERE a.status_request_id IS NULL
      AND (a.last_synced_at IS NULL OR a.last_synced_at < now() - interval '6 hours')
      AND (a.sync_requested_at IS NULL OR a.sync_requested_at < now() - interval '15 minutes')
    ORDER BY a.last_synced_at NULLS FIRST
    LIMIT greatest(0, least(_limit, 5))
  LOOP
    PERFORM public.cf_enqueue_sync(r.user_id);
  END LOOP;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cf_sync_tick_limit(int) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.cf_sync_tick()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.cf_sync_tick_limit(3);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cf_sync_tick() FROM PUBLIC, anon, authenticated;

-- RF-047: al consultar el Scoreboard se procesan respuestas pendientes y se refrescan cuentas antiguas
CREATE OR REPLACE FUNCTION public.refresh_scoreboard()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  PERFORM public.cf_sync_tick_limit(2);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.refresh_scoreboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_scoreboard() TO authenticated;

SELECT cron.schedule('guapa-codeforces-sync', '7 * * * *', 'SELECT public.cf_sync_tick()');