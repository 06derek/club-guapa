CREATE TYPE public.app_role AS ENUM ('admin', 'user');

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL CHECK (char_length(full_name) BETWEEN 3 AND 100),
  username text NOT NULL CHECK (username ~ '^[A-Za-z0-9_]{3,24}$'),
  avatar_url text,
  bio text CHECK (bio IS NULL OR char_length(bio) <= 500),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX profiles_username_lower_idx ON public.profiles (lower(username));
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT, INSERT, DELETE ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE OR REPLACE FUNCTION public.is_unam_email(_email text)
RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT lower(coalesce(_email, '')) ~ '^[^@\s]+@([a-z0-9-]+\.)*unam\.mx$'
$$;

CREATE OR REPLACE FUNCTION public.username_available(_username text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT NOT EXISTS (SELECT 1 FROM public.profiles WHERE lower(username) = lower(trim(_username)))
$$;
GRANT EXECUTE ON FUNCTION public.username_available(text) TO anon, authenticated;

CREATE POLICY "Perfiles activos, propio o admin" ON public.profiles FOR SELECT TO authenticated
  USING (is_active OR id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can update profiles"
  ON public.profiles FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users can view own roles"
  ON public.user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can grant roles"
  ON public.user_roles FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can revoke roles"
  ON public.user_roles FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
CREATE TRIGGER profiles_touch BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  _full_name text := trim(coalesce(NEW.raw_user_meta_data->>'full_name', ''));
  _username text := trim(coalesce(NEW.raw_user_meta_data->>'username', ''));
BEGIN
  IF NOT public.is_unam_email(NEW.email) THEN
    RAISE EXCEPTION 'Solo se permiten correos institucionales de la UNAM';
  END IF;
  IF char_length(_full_name) < 3 OR char_length(_full_name) > 100 THEN
    RAISE EXCEPTION 'Nombre completo inválido';
  END IF;
  IF _username !~ '^[A-Za-z0-9_]{3,24}$' THEN
    RAISE EXCEPTION 'Nombre de usuario inválido';
  END IF;
  INSERT INTO public.profiles (id, full_name, username) VALUES (NEW.id, _full_name, _username);
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user');
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===== Contenido público =====
CREATE TABLE public.activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 120),
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 3 AND 1000),
  tag text NOT NULL CHECK (char_length(btrim(tag)) BETWEEN 2 AND 40),
  activity_date date NOT NULL,
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.activities TO anon;
GRANT SELECT, INSERT ON public.activities TO authenticated;
GRANT ALL ON public.activities TO service_role;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Actividades visibles para todos" ON public.activities FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Solo admins registran actividades" ON public.activities FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid());

CREATE TABLE public.schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time time NOT NULL,
  end_time time NOT NULL,
  activity text NOT NULL CHECK (char_length(btrim(activity)) BETWEEN 3 AND 120),
  place text NOT NULL CHECK (char_length(btrim(place)) BETWEEN 2 AND 120),
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT schedules_time_order CHECK (end_time > start_time)
);
GRANT SELECT ON public.schedules TO anon;
GRANT SELECT, INSERT ON public.schedules TO authenticated;
GRANT ALL ON public.schedules TO service_role;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Horarios visibles para todos" ON public.schedules FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Solo admins registran horarios" ON public.schedules FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid());

-- ===== Equipos =====
CREATE TABLE public.teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 2 AND 60),
  description text CHECK (description IS NULL OR char_length(description) <= 300),
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX teams_name_unique ON public.teams (lower(btrim(name)));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.teams TO authenticated;
GRANT ALL ON public.teams TO service_role;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.team_members (
  team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  added_by uuid NOT NULL DEFAULT auth.uid(),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (team_id, user_id)
);
CREATE INDEX team_members_user_idx ON public.team_members (user_id);
GRANT SELECT, INSERT, DELETE ON public.team_members TO authenticated;
GRANT ALL ON public.team_members TO service_role;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_team_member(_team_id uuid, _user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.team_members WHERE team_id = _team_id AND user_id = _user_id)
$$;

CREATE POLICY "Equipos visibles para integrantes y admins" ON public.teams FOR SELECT TO authenticated
  USING (created_by = auth.uid() OR public.is_team_member(id, auth.uid()) OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Usuarios crean equipos propios" ON public.teams FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());
CREATE POLICY "Admins modifican equipos" ON public.teams FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins eliminan equipos" ON public.teams FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Integrantes visibles para su equipo y admins" ON public.team_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_team_member(team_id, auth.uid()) OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Integrantes o admins agregan" ON public.team_members FOR INSERT TO authenticated
  WITH CHECK (
    added_by = auth.uid()
    AND (public.is_team_member(team_id, auth.uid()) OR public.has_role(auth.uid(), 'admin'))
  );
CREATE POLICY "Admins retiran integrantes" ON public.team_members FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.enforce_team_member_rules()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _count int;
BEGIN
  PERFORM 1 FROM public.teams WHERE id = NEW.team_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'TEAM_NOT_FOUND' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.user_id AND is_active) THEN
    RAISE EXCEPTION 'USER_NOT_ELIGIBLE' USING ERRCODE = 'P0001';
  END IF;
  SELECT count(*) INTO _count FROM public.team_members WHERE team_id = NEW.team_id;
  IF _count >= 5 THEN
    RAISE EXCEPTION 'TEAM_FULL' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER team_members_rules BEFORE INSERT ON public.team_members
  FOR EACH ROW EXECUTE FUNCTION public.enforce_team_member_rules();

CREATE OR REPLACE FUNCTION public.add_team_creator()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.team_members (team_id, user_id, added_by) VALUES (NEW.id, NEW.created_by, NEW.created_by);
  RETURN NEW;
END;
$$;
CREATE TRIGGER teams_add_creator AFTER INSERT ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.add_team_creator();

REVOKE EXECUTE ON FUNCTION public.enforce_team_member_rules() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.add_team_creator() FROM PUBLIC, anon, authenticated;