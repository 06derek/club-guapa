-- Datos de contacto editables por administradores (correo, ubicación, Facebook, Discord)
ALTER TABLE public.site_settings DROP CONSTRAINT site_settings_key_check;
ALTER TABLE public.site_settings
  ADD CONSTRAINT site_settings_key_check CHECK (key IN ('event_theme', 'contact_email', 'contact_location', 'social_facebook', 'social_discord')),
  ADD CONSTRAINT site_settings_value_length CHECK (char_length(value) <= 500),
  ADD CONSTRAINT site_settings_social_url CHECK (key NOT LIKE 'social_%' OR value = '' OR value ~* '^https?://\S+$'),
  ADD CONSTRAINT site_settings_contact_email CHECK (key <> 'contact_email' OR value = '' OR value ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$');

INSERT INTO public.site_settings (key, value) VALUES
  ('contact_email', 'guapa.acatlan@ejemplo.mx'),
  ('contact_location', 'CEDETEC, FES Acatlán, Naucalpan, Estado de México'),
  ('social_facebook', 'https://facebook.com'),
  ('social_discord', 'https://discord.com')
ON CONFLICT (key) DO NOTHING;