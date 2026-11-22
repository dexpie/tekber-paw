-- Representasi auth.users agar relasi akun terlihat.
-- Ini untuk diagram saja; auth.users dikelola oleh Supabase.
CREATE TABLE auth.users (
  id UUID PRIMARY KEY
);

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE public.cats (
  id UUID PRIMARY KEY,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  behavior TEXT NOT NULL,
  photo_path TEXT,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE public.sightings (
  id UUID PRIMARY KEY,
  cat_id UUID NOT NULL REFERENCES public.cats(id),
  reported_by UUID NOT NULL REFERENCES auth.users(id),
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  seen_at TIMESTAMPTZ NOT NULL,
  note TEXT NOT NULL,
  photo_path TEXT,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE public.cat_reports (
  id UUID PRIMARY KEY,
  cat_id UUID NOT NULL REFERENCES public.cats(id),
  reported_by UUID NOT NULL REFERENCES auth.users(id),
  reason TEXT NOT NULL,
  details TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  UNIQUE (cat_id, reported_by)
);

CREATE TABLE public.cat_favorites (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cat_id UUID NOT NULL REFERENCES public.cats(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (user_id, cat_id)
);

CREATE TABLE pawmap_private.admin_users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  granted_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE public.admin_broadcasts (
  id UUID PRIMARY KEY,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  audience TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  processed_at TIMESTAMPTZ,
  status TEXT NOT NULL,
  recipients_count INTEGER NOT NULL,
  sent_count INTEGER NOT NULL,
  failed_count INTEGER NOT NULL
);

CREATE TABLE public.push_devices (
  installation_id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  refreshed_at TIMESTAMPTZ NOT NULL,
  enabled BOOLEAN NOT NULL
);

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  cat_id UUID REFERENCES public.cats(id) ON DELETE SET NULL,
  broadcast_id UUID REFERENCES public.admin_broadcasts(id) ON DELETE SET NULL,
  event_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  read_at TIMESTAMPTZ,
  UNIQUE (user_id, event_key)
);

CREATE TABLE pawmap_private.user_activity (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  last_seen_at TIMESTAMPTZ NOT NULL,
  last_reminder_at TIMESTAMPTZ
);

CREATE TABLE pawmap_private.notification_outbox (
  id UUID PRIMARY KEY,
  notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  installation_id UUID NOT NULL REFERENCES public.push_devices(installation_id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  available_at TIMESTAMPTZ NOT NULL,
  lease_id UUID,
  lease_until TIMESTAMPTZ,
  claim_token_hash TEXT,
  error_code TEXT,
  updated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (notification_id, installation_id)
);

CREATE TABLE public.cat_help_requests (
  id UUID PRIMARY KEY,
  cat_id UUID NOT NULL REFERENCES public.cats(id),
  reported_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  condition TEXT NOT NULL,
  details TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);