CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ===== Ayudantes =====
CREATE OR REPLACE FUNCTION public.is_active_user(_uid uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = _uid AND is_active)
$$;

-- Usuarios desactivados no crean equipos ni agregan integrantes
DROP POLICY IF EXISTS "Usuarios crean equipos propios" ON public.teams;
CREATE POLICY "Usuarios crean equipos propios" ON public.teams FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid() AND public.is_active_user(auth.uid()));
DROP POLICY IF EXISTS "Integrantes o admins agregan" ON public.team_members;
CREATE POLICY "Integrantes o admins agregan" ON public.team_members FOR INSERT TO authenticated
  WITH CHECK (
    added_by = auth.uid() AND public.is_active_user(auth.uid())
    AND (public.is_team_member(team_id, auth.uid()) OR public.has_role(auth.uid(), 'admin'))
  );
-- RF-038: abandonar un equipo
CREATE POLICY "Usuarios abandonan sus equipos" ON public.team_members FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- RF-009: admins eliminan actividades y horarios
GRANT DELETE ON public.activities TO authenticated;
GRANT DELETE ON public.schedules TO authenticated;
CREATE POLICY "Admins eliminan actividades" ON public.activities FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins eliminan horarios" ON public.schedules FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- RF-022: edición del propio perfil (sin tocar is_active)
CREATE OR REPLACE FUNCTION public.update_my_profile(_full_name text, _username text, _bio text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _uid uuid := auth.uid();
  _fn text := btrim(coalesce(_full_name, ''));
  _un text := btrim(coalesce(_username, ''));
  _b text := nullif(btrim(coalesce(_bio, '')), '');
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED' USING ERRCODE = '42501'; END IF;
  IF char_length(_fn) < 3 OR char_length(_fn) > 100 THEN RAISE EXCEPTION 'INVALID_FULL_NAME'; END IF;
  IF _un !~ '^[A-Za-z0-9_]{3,24}$' THEN RAISE EXCEPTION 'INVALID_USERNAME'; END IF;
  IF _b IS NOT NULL AND char_length(_b) > 500 THEN RAISE EXCEPTION 'INVALID_BIO'; END IF;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE lower(username) = lower(_un) AND id <> _uid) THEN
    RAISE EXCEPTION 'USERNAME_TAKEN';
  END IF;
  UPDATE public.profiles SET full_name = _fn, username = _un, bio = _b WHERE id = _uid;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.update_my_profile(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_profile(text, text, text) TO authenticated;

-- ===== Recursos (RF-026 a RF-032) =====
CREATE TYPE public.resource_visibility AS ENUM ('public', 'members');

CREATE TABLE public.resource_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 2 AND 60),
  sort_order int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX resource_categories_name_unique ON public.resource_categories (lower(btrim(name)));
GRANT SELECT ON public.resource_categories TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.resource_categories TO authenticated;
GRANT ALL ON public.resource_categories TO service_role;
ALTER TABLE public.resource_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Categorías visibles para todos" ON public.resource_categories FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Admins gestionan categorías (alta)" ON public.resource_categories FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins gestionan categorías (edición)" ON public.resource_categories FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins gestionan categorías (baja)" ON public.resource_categories FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

INSERT INTO public.resource_categories (name, sort_order) VALUES
  ('Fundamentos', 10), ('Estructuras de datos', 20), ('Grafos', 30), ('Programación dinámica', 40),
  ('Matemáticas', 50), ('Cadenas', 60), ('Guías y referencias', 70);

CREATE TABLE public.resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 120),
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 3 AND 1000),
  url text NOT NULL CHECK (url ~* '^https?://[^\s]+$' AND char_length(url) <= 500),
  category_id uuid REFERENCES public.resource_categories(id) ON DELETE SET NULL,
  visibility public.resource_visibility NOT NULL DEFAULT 'public',
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX resources_category_idx ON public.resources (category_id);
GRANT SELECT ON public.resources TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.resources TO authenticated;
GRANT ALL ON public.resources TO service_role;
ALTER TABLE public.resources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Recursos públicos para visitantes" ON public.resources FOR SELECT TO anon USING (visibility = 'public');
CREATE POLICY "Recursos visibles para miembros" ON public.resources FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins registran recursos" ON public.resources FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid());
CREATE POLICY "Admins modifican recursos" ON public.resources FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins eliminan recursos" ON public.resources FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));
CREATE TRIGGER resources_touch BEFORE UPDATE ON public.resources
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ===== Calendario (RF-061 a RF-066) =====
CREATE TABLE public.calendar_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 120),
  platform text NOT NULL CHECK (char_length(btrim(platform)) BETWEEN 2 AND 60),
  starts_at timestamptz NOT NULL,
  duration_minutes int CHECK (duration_minutes IS NULL OR duration_minutes BETWEEN 1 AND 20160),
  url text CHECK (url IS NULL OR (url ~* '^https?://[^\s]+$' AND char_length(url) <= 500)),
  description text CHECK (description IS NULL OR char_length(description) <= 500),
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX calendar_events_starts_idx ON public.calendar_events (starts_at);
GRANT SELECT ON public.calendar_events TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.calendar_events TO authenticated;
GRANT ALL ON public.calendar_events TO service_role;
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Calendario público" ON public.calendar_events FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Admins registran competencias del calendario" ON public.calendar_events FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid());
CREATE POLICY "Admins modifican competencias del calendario" ON public.calendar_events FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins eliminan competencias del calendario" ON public.calendar_events FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- ===== Competencias externas (RF-051 a RF-060, RF-070) =====
CREATE TABLE public.external_platforms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 2 AND 60),
  url text CHECK (url IS NULL OR (url ~* '^https?://[^\s]+$' AND char_length(url) <= 300)),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX external_platforms_name_unique ON public.external_platforms (lower(btrim(name)));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.external_platforms TO authenticated;
GRANT ALL ON public.external_platforms TO service_role;
ALTER TABLE public.external_platforms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Plataformas visibles para miembros" ON public.external_platforms FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins agregan plataformas" ON public.external_platforms FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins modifican plataformas" ON public.external_platforms FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins eliminan plataformas" ON public.external_platforms FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

INSERT INTO public.external_platforms (name, url) VALUES
  ('omegaUp', 'https://omegaup.com'), ('AtCoder', 'https://atcoder.jp'), ('LeetCode', 'https://leetcode.com'),
  ('HackerRank', 'https://www.hackerrank.com'), ('CSES', 'https://cses.fi'), ('GUINIJuez', NULL),
  ('ICPC', 'https://icpc.global'), ('Otra', NULL);

CREATE TABLE public.external_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform_id uuid NOT NULL REFERENCES public.external_platforms(id) ON DELETE RESTRICT,
  contest_name text NOT NULL CHECK (char_length(btrim(contest_name)) BETWEEN 3 AND 120),
  contest_date date NOT NULL,
  solved int NOT NULL CHECK (solved BETWEEN 0 AND 100),
  place int CHECK (place IS NULL OR place >= 1),
  participants int CHECK (participants IS NULL OR participants >= 1),
  score numeric(10,2) CHECK (score IS NULL OR score >= 0),
  notes text CHECK (notes IS NULL OR char_length(notes) <= 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT external_results_place_le_participants CHECK (place IS NULL OR participants IS NULL OR place <= participants)
);
CREATE INDEX external_results_user_idx ON public.external_results (user_id, contest_date DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.external_results TO authenticated;
GRANT ALL ON public.external_results TO service_role;
ALTER TABLE public.external_results ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Competencias propias o admin (lectura)" ON public.external_results FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Usuarios registran sus competencias" ON public.external_results FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND public.is_active_user(auth.uid()));
CREATE POLICY "Competencias propias o admin (edición)" ON public.external_results FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'))
  WITH CHECK (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Competencias propias o admin (baja)" ON public.external_results FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.validate_external_result()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.contest_date > (now() AT TIME ZONE 'America/Mexico_City')::date THEN
    RAISE EXCEPTION 'DATE_IN_FUTURE' USING ERRCODE = 'P0001';
  END IF;
  IF NEW.contest_date < DATE '2000-01-01' THEN
    RAISE EXCEPTION 'DATE_TOO_OLD' USING ERRCODE = 'P0001';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    NEW.user_id := OLD.user_id;
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER external_results_validate BEFORE INSERT OR UPDATE ON public.external_results
  FOR EACH ROW EXECUTE FUNCTION public.validate_external_result();
REVOKE EXECUTE ON FUNCTION public.validate_external_result() FROM PUBLIC, anon, authenticated;

-- ===== Ajustes del sitio (RF-089) =====
CREATE TABLE public.site_settings (
  key text PRIMARY KEY CHECK (key IN ('event_theme')),
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT site_settings_event_theme CHECK (key <> 'event_theme' OR value IN ('none', 'muertos', 'navidad', 'icpc'))
);
GRANT SELECT ON public.site_settings TO anon;
GRANT SELECT, UPDATE ON public.site_settings TO authenticated;
GRANT ALL ON public.site_settings TO service_role;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Ajustes visibles para todos" ON public.site_settings FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Admins cambian ajustes" ON public.site_settings FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE TRIGGER site_settings_touch BEFORE UPDATE ON public.site_settings
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
INSERT INTO public.site_settings (key, value) VALUES ('event_theme', 'none');