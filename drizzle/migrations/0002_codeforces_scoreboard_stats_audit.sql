-- ===== Codeforces (RF-041 a RF-050) =====
CREATE TABLE public.codeforces_accounts (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  handle text NOT NULL CHECK (handle ~ '^[A-Za-z0-9_.-]{1,24}$'),
  rating int,
  max_rating int,
  cf_rank text,
  max_rank text,
  avatar_url text,
  linked_at timestamptz NOT NULL DEFAULT now(),
  last_synced_at timestamptz,
  sync_status text NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'ok', 'error')),
  sync_error text,
  sync_requested_at timestamptz,
  full_synced boolean NOT NULL DEFAULT false,
  status_request_id bigint,
  info_request_id bigint
);
CREATE UNIQUE INDEX codeforces_accounts_handle_unique ON public.codeforces_accounts (lower(handle));
GRANT SELECT ON public.codeforces_accounts TO authenticated;
GRANT ALL ON public.codeforces_accounts TO service_role;
ALTER TABLE public.codeforces_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Cuenta de Codeforces propia o admin" ON public.codeforces_accounts FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.cf_solved_problems (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  problem_key text NOT NULL,
  contest_id int,
  problem_index text NOT NULL,
  name text NOT NULL,
  rating int,
  tags text[] NOT NULL DEFAULT '{}',
  first_accepted_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, problem_key)
);
CREATE INDEX cf_solved_problems_time_idx ON public.cf_solved_problems (user_id, first_accepted_at);
GRANT SELECT ON public.cf_solved_problems TO authenticated;
GRANT ALL ON public.cf_solved_problems TO service_role;
ALTER TABLE public.cf_solved_problems ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Problemas propios o admin" ON public.cf_solved_problems FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

-- Encola la descarga de datos públicos de Codeforces (se ejecuta al confirmar la transacción)
CREATE OR REPLACE FUNCTION public.cf_enqueue_sync(_uid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  _acc public.codeforces_accounts;
  _sreq bigint;
  _ireq bigint;
BEGIN
  SELECT * INTO _acc FROM public.codeforces_accounts WHERE user_id = _uid FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  _sreq := net.http_get(
    url := 'https://codeforces.com/api/user.status?handle=' || _acc.handle
      || CASE WHEN _acc.full_synced THEN '&from=1&count=500' ELSE '' END,
    timeout_milliseconds := 30000
  );
  _ireq := net.http_get(
    url := 'https://codeforces.com/api/user.info?handles=' || _acc.handle,
    timeout_milliseconds := 15000
  );
  UPDATE public.codeforces_accounts
     SET status_request_id = _sreq, info_request_id = _ireq, sync_status = 'pending',
         sync_requested_at = now(), sync_error = NULL
   WHERE user_id = _uid;
END;
$$;

-- Procesa la respuesta de Codeforces; conserva los datos previos si falla (RF-049)
CREATE OR REPLACE FUNCTION public.cf_process_sync(_uid uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  _acc public.codeforces_accounts;
  _sr record;
  _ir record;
  _json jsonb;
  _info jsonb;
BEGIN
  SELECT * INTO _acc FROM public.codeforces_accounts WHERE user_id = _uid FOR UPDATE;
  IF NOT FOUND THEN RETURN 'none'; END IF;
  IF _acc.status_request_id IS NULL THEN RETURN _acc.sync_status; END IF;

  SELECT id, status_code, content, timed_out INTO _sr FROM net._http_response WHERE id = _acc.status_request_id;
  IF NOT FOUND THEN
    IF _acc.sync_requested_at < now() - interval '3 minutes' THEN
      UPDATE public.codeforces_accounts
         SET sync_status = 'error', sync_error = 'Codeforces no respondió a tiempo',
             status_request_id = NULL, info_request_id = NULL
       WHERE user_id = _uid;
      RETURN 'error';
    END IF;
    RETURN 'pending';
  END IF;
  SELECT id, status_code, content, timed_out INTO _ir FROM net._http_response WHERE id = _acc.info_request_id;
  IF NOT FOUND AND _acc.sync_requested_at > now() - interval '45 seconds' THEN
    RETURN 'pending';
  END IF;

  -- Handle inexistente: se elimina la vinculación
  BEGIN
    _json := _sr.content::jsonb;
  EXCEPTION WHEN OTHERS THEN
    _json := NULL;
  END;
  IF _json->>'status' = 'FAILED' AND coalesce(_json->>'comment', '') ILIKE '%not found%' THEN
    DELETE FROM public.cf_solved_problems WHERE user_id = _uid;
    DELETE FROM public.codeforces_accounts WHERE user_id = _uid;
    RETURN 'not_found';
  END IF;

  BEGIN
    IF coalesce(_sr.timed_out, false) OR _sr.status_code IS DISTINCT FROM 200 THEN
      RAISE EXCEPTION 'bad response';
    END IF;
    _json := _sr.content::jsonb;
    IF _json->>'status' IS DISTINCT FROM 'OK' THEN RAISE EXCEPTION 'bad status'; END IF;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.codeforces_accounts
       SET sync_status = 'error', sync_error = 'Codeforces no respondió correctamente',
           status_request_id = NULL, info_request_id = NULL
     WHERE user_id = _uid;
    RETURN 'error';
  END;

  -- RF-050: un problema cuenta una sola vez por usuario (primera aceptación)
  INSERT INTO public.cf_solved_problems AS c
    (user_id, problem_key, contest_id, problem_index, name, rating, tags, first_accepted_at)
  SELECT DISTINCT ON (x.k) _uid, x.k, x.cid, x.idx, x.nm, x.rt, x.tg, x.ts
  FROM (
    SELECT coalesce(p->>'contestId', p->>'problemsetName', 'x') || '-' || (p->>'index') AS k,
           (p->>'contestId')::int AS cid,
           p->>'index' AS idx,
           coalesce(p->>'name', '') AS nm,
           (p->>'rating')::int AS rt,
           ARRAY(SELECT jsonb_array_elements_text(coalesce(p->'tags', '[]'::jsonb))) AS tg,
           to_timestamp((s->>'creationTimeSeconds')::bigint) AS ts
    FROM jsonb_array_elements(_json->'result') AS s
    CROSS JOIN LATERAL (SELECT s->'problem' AS p) AS pp
    WHERE s->>'verdict' = 'OK' AND p->>'index' IS NOT NULL
  ) AS x
  ORDER BY x.k, x.ts
  ON CONFLICT (user_id, problem_key) DO UPDATE
    SET first_accepted_at = LEAST(c.first_accepted_at, EXCLUDED.first_accepted_at),
        rating = coalesce(EXCLUDED.rating, c.rating),
        tags = EXCLUDED.tags,
        name = EXCLUDED.name;

  IF _ir.id IS NOT NULL AND _ir.status_code = 200 THEN
    BEGIN
      _info := (_ir.content::jsonb)->'result'->0;
      UPDATE public.codeforces_accounts
         SET handle = coalesce(_info->>'handle', handle), rating = (_info->>'rating')::int,
             max_rating = (_info->>'maxRating')::int, cf_rank = _info->>'rank', max_rank = _info->>'maxRank',
             avatar_url = _info->>'titlePhoto'
       WHERE user_id = _uid;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  UPDATE public.codeforces_accounts
     SET sync_status = 'ok', sync_error = NULL, last_synced_at = now(), full_synced = true,
         status_request_id = NULL, info_request_id = NULL
   WHERE user_id = _uid;
  RETURN 'ok';
END;
$$;

-- RF-041: vincular cuenta (la existencia del handle se confirma al sincronizar)
CREATE OR REPLACE FUNCTION public.link_codeforces(_handle text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _uid uuid := auth.uid();
  _h text := btrim(coalesce(_handle, ''));
  _old text;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  IF NOT public.is_active_user(_uid) THEN RAISE EXCEPTION 'USER_NOT_ELIGIBLE'; END IF;
  IF _h !~ '^[A-Za-z0-9_.-]{3,24}$' THEN RAISE EXCEPTION 'CF_HANDLE_INVALID'; END IF;
  IF EXISTS (SELECT 1 FROM public.codeforces_accounts WHERE lower(handle) = lower(_h) AND user_id <> _uid) THEN
    RAISE EXCEPTION 'CF_HANDLE_TAKEN';
  END IF;

  SELECT handle INTO _old FROM public.codeforces_accounts WHERE user_id = _uid;
  IF _old IS NOT NULL AND lower(_old) <> lower(_h) THEN
    DELETE FROM public.cf_solved_problems WHERE user_id = _uid;
  END IF;

  INSERT INTO public.codeforces_accounts AS a (user_id, handle, linked_at, full_synced, sync_status)
  VALUES (_uid, _h, now(), false, 'pending')
  ON CONFLICT (user_id) DO UPDATE SET
    handle = EXCLUDED.handle,
    linked_at = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.linked_at ELSE now() END,
    full_synced = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.full_synced ELSE false END,
    last_synced_at = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.last_synced_at ELSE NULL END,
    rating = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.rating ELSE NULL END,
    max_rating = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.max_rating ELSE NULL END,
    cf_rank = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.cf_rank ELSE NULL END,
    max_rank = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.max_rank ELSE NULL END,
    avatar_url = CASE WHEN lower(a.handle) = lower(EXCLUDED.handle) THEN a.avatar_url ELSE NULL END,
    status_request_id = NULL, info_request_id = NULL, sync_requested_at = NULL;

  PERFORM public.cf_enqueue_sync(_uid);
  RETURN _h;
END;
$$;

CREATE OR REPLACE FUNCTION public.unlink_codeforces()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  DELETE FROM public.cf_solved_problems WHERE user_id = auth.uid();
  DELETE FROM public.codeforces_accounts WHERE user_id = auth.uid();
END;
$$;

-- RF-042 / RF-047: actualización bajo demanda
CREATE OR REPLACE FUNCTION public.request_my_cf_sync()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _acc public.codeforces_accounts;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  SELECT * INTO _acc FROM public.codeforces_accounts WHERE user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'CF_NOT_LINKED'; END IF;
  IF _acc.status_request_id IS NOT NULL AND _acc.sync_requested_at > now() - interval '3 minutes' THEN
    RETURN 'pending';
  END IF;
  IF _acc.sync_requested_at > now() - interval '60 seconds' THEN RAISE EXCEPTION 'CF_SYNC_TOO_SOON'; END IF;
  PERFORM public.cf_enqueue_sync(auth.uid());
  RETURN 'pending';
END;
$$;

CREATE OR REPLACE FUNCTION public.process_my_cf_sync()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  RETURN public.cf_process_sync(auth.uid());
END;
$$;

-- Sincronización automática periódica
CREATE OR REPLACE FUNCTION public.cf_sync_tick()
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
    LIMIT 2
  LOOP
    PERFORM public.cf_enqueue_sync(r.user_id);
  END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cf_enqueue_sync(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.cf_process_sync(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.cf_sync_tick() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.link_codeforces(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.unlink_codeforces() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.request_my_cf_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.process_my_cf_sync() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.link_codeforces(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlink_codeforces() TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_my_cf_sync() TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_my_cf_sync() TO authenticated;

-- ===== Scoreboard (RF-044 a RF-048) =====
CREATE OR REPLACE FUNCTION public.get_scoreboard(_from date, _to date)
RETURNS TABLE (
  user_id uuid, full_name text, username text, handle text, rating int, cf_rank text,
  solved bigint, last_solved_at timestamptz, last_synced_at timestamptz, sync_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
#variable_conflict use_column
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  IF _from IS NOT NULL AND _to IS NOT NULL AND _from > _to THEN RAISE EXCEPTION 'INVALID_PERIOD'; END IF;
  RETURN QUERY
  SELECT p.id, p.full_name, p.username, a.handle, a.rating, a.cf_rank,
         count(s.problem_key), max(s.first_accepted_at), a.last_synced_at, a.sync_status
  FROM public.profiles p
  LEFT JOIN public.codeforces_accounts a ON a.user_id = p.id
  LEFT JOIN public.cf_solved_problems s ON s.user_id = p.id
    AND (_from IS NULL OR s.first_accepted_at >= (_from::timestamp AT TIME ZONE 'America/Mexico_City'))
    AND (_to IS NULL OR s.first_accepted_at < ((_to + 1)::timestamp AT TIME ZONE 'America/Mexico_City'))
  WHERE p.is_active
  GROUP BY p.id, p.full_name, p.username, a.handle, a.rating, a.cf_rank, a.last_synced_at, a.sync_status
  ORDER BY (a.handle IS NULL), count(s.problem_key) DESC, max(s.first_accepted_at) ASC NULLS LAST,
           a.rating DESC NULLS LAST, p.full_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_scoreboard(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_scoreboard(date, date) TO authenticated;

-- ===== Estadísticas (RF-079 a RF-082) =====
CREATE OR REPLACE FUNCTION public.get_user_stats(_user uuid, _from date, _to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _lo timestamptz;
  _hi timestamptz;
  _res jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  IF _user <> auth.uid() AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501';
  END IF;
  IF _from IS NOT NULL AND _to IS NOT NULL AND _from > _to THEN RAISE EXCEPTION 'INVALID_PERIOD'; END IF;
  _lo := CASE WHEN _from IS NULL THEN '-infinity'::timestamptz ELSE (_from::timestamp AT TIME ZONE 'America/Mexico_City') END;
  _hi := CASE WHEN _to IS NULL THEN 'infinity'::timestamptz ELSE ((_to + 1)::timestamp AT TIME ZONE 'America/Mexico_City') END;

  SELECT jsonb_build_object(
    'account', (SELECT to_jsonb(a) - 'status_request_id' - 'info_request_id' FROM public.codeforces_accounts a WHERE a.user_id = _user),
    'total_solved', (SELECT count(*) FROM public.cf_solved_problems WHERE user_id = _user),
    'period_solved', (SELECT count(*) FROM public.cf_solved_problems WHERE user_id = _user AND first_accepted_at >= _lo AND first_accepted_at < _hi),
    'by_rating', coalesce((
      SELECT jsonb_agg(jsonb_build_object('bucket', b, 'count', c) ORDER BY b NULLS LAST)
      FROM (
        SELECT CASE WHEN rating IS NULL THEN NULL ELSE (rating / 200) * 200 END AS b, count(*) AS c
        FROM public.cf_solved_problems
        WHERE user_id = _user AND first_accepted_at >= _lo AND first_accepted_at < _hi
        GROUP BY 1
      ) q), '[]'::jsonb),
    'top_tags', coalesce((
      SELECT jsonb_agg(jsonb_build_object('tag', t, 'count', c) ORDER BY c DESC, t)
      FROM (
        SELECT t, count(*) AS c
        FROM public.cf_solved_problems, unnest(tags) AS t
        WHERE user_id = _user AND first_accepted_at >= _lo AND first_accepted_at < _hi
        GROUP BY t ORDER BY count(*) DESC, t LIMIT 10
      ) q), '[]'::jsonb),
    'monthly', coalesce((
      SELECT jsonb_agg(jsonb_build_object('month', m, 'count', c) ORDER BY m)
      FROM (
        SELECT to_char(first_accepted_at AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') AS m, count(*) AS c
        FROM public.cf_solved_problems
        WHERE user_id = _user AND first_accepted_at >= greatest(_lo, now() - interval '24 months') AND first_accepted_at < _hi
        GROUP BY 1
      ) q), '[]'::jsonb),
    'recent', coalesce((
      SELECT jsonb_agg(to_jsonb(q) ORDER BY q.first_accepted_at DESC)
      FROM (
        SELECT problem_key, contest_id, problem_index, name, rating, first_accepted_at
        FROM public.cf_solved_problems
        WHERE user_id = _user AND first_accepted_at >= _lo AND first_accepted_at < _hi
        ORDER BY first_accepted_at DESC LIMIT 30
      ) q), '[]'::jsonb),
    'external', (
      SELECT jsonb_build_object('count', count(*), 'best_place', min(place), 'solved', coalesce(sum(solved), 0))
      FROM public.external_results
      WHERE user_id = _user
        AND (_from IS NULL OR contest_date >= _from) AND (_to IS NULL OR contest_date <= _to)
    )
  ) INTO _res;
  RETURN _res;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_user_stats(uuid, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_stats(uuid, date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_team_stats(_team uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _res jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  IF NOT public.is_team_member(_team, auth.uid()) AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'members', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', p.id, 'full_name', p.full_name, 'username', p.username,
        'handle', a.handle, 'rating', a.rating, 'cf_rank', a.cf_rank,
        'solved_total', (SELECT count(*) FROM public.cf_solved_problems s WHERE s.user_id = p.id),
        'solved_30d', (SELECT count(*) FROM public.cf_solved_problems s WHERE s.user_id = p.id AND s.first_accepted_at >= now() - interval '30 days'),
        'external_count', (SELECT count(*) FROM public.external_results e WHERE e.user_id = p.id)
      ) ORDER BY p.full_name)
      FROM public.team_members tm
      JOIN public.profiles p ON p.id = tm.user_id
      LEFT JOIN public.codeforces_accounts a ON a.user_id = p.id
      WHERE tm.team_id = _team), '[]'::jsonb),
    'distinct_solved', (
      SELECT count(DISTINCT s.problem_key) FROM public.cf_solved_problems s
      JOIN public.team_members tm ON tm.user_id = s.user_id AND tm.team_id = _team),
    'distinct_solved_30d', (
      SELECT count(DISTINCT s.problem_key) FROM public.cf_solved_problems s
      JOIN public.team_members tm ON tm.user_id = s.user_id AND tm.team_id = _team
      WHERE s.first_accepted_at >= now() - interval '30 days'),
    'avg_rating', (
      SELECT round(avg(a.rating)) FROM public.codeforces_accounts a
      JOIN public.team_members tm ON tm.user_id = a.user_id AND tm.team_id = _team
      WHERE a.rating IS NOT NULL)
  ) INTO _res;
  RETURN _res;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_team_stats(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_stats(uuid) TO authenticated;

-- ===== Auditoría de acciones administrativas (RF-075) =====
CREATE TABLE public.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id uuid,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_log_created_idx ON public.audit_log (created_at DESC);
GRANT SELECT ON public.audit_log TO authenticated;
GRANT ALL ON public.audit_log TO service_role;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Solo admins consultan la auditoría" ON public.audit_log FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.audit_admin_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _row jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_role(auth.uid(), 'admin') THEN RETURN NULL; END IF;
  _row := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
  IF TG_TABLE_NAME = 'external_results' AND (_row->>'user_id') = auth.uid()::text THEN RETURN NULL; END IF;
  INSERT INTO public.audit_log (actor_id, action, entity, entity_id, details)
  VALUES (
    auth.uid(), TG_OP, TG_TABLE_NAME,
    coalesce(_row->>'id', _row->>'key', _row->>'user_id'),
    jsonb_strip_nulls(jsonb_build_object(
      'title', _row->>'title', 'name', coalesce(_row->>'name', _row->>'contest_name', _row->>'full_name'),
      'role', _row->>'role', 'user_id', _row->>'user_id', 'is_active', _row->'is_active', 'value', _row->>'value'
    ))
  );
  RETURN NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.audit_admin_change() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER audit_activities AFTER INSERT OR UPDATE OR DELETE ON public.activities FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_schedules AFTER INSERT OR UPDATE OR DELETE ON public.schedules FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_resources AFTER INSERT OR UPDATE OR DELETE ON public.resources FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_resource_categories AFTER INSERT OR UPDATE OR DELETE ON public.resource_categories FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_calendar_events AFTER INSERT OR UPDATE OR DELETE ON public.calendar_events FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_external_platforms AFTER INSERT OR UPDATE OR DELETE ON public.external_platforms FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_external_results AFTER UPDATE OR DELETE ON public.external_results FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_user_roles AFTER INSERT OR DELETE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_site_settings AFTER UPDATE ON public.site_settings FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_teams AFTER UPDATE OR DELETE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.audit_admin_change();
CREATE TRIGGER audit_profiles_active AFTER UPDATE OF is_active ON public.profiles FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active) EXECUTE FUNCTION public.audit_admin_change();