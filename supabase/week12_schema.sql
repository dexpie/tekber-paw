-- Jalankan sekali di SQL Editor proyek latihan Kelompok 4.
begin;

create table public.cats (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  description text not null check (char_length(btrim(description)) between 1 and 300),
  created_by uuid default auth.uid() references auth.users (id) on delete set null
);

create table public.sightings (
  id uuid primary key default gen_random_uuid(),
  cat_id uuid not null references public.cats (id),
  reported_by uuid default auth.uid() references auth.users (id) on delete set null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  seen_at timestamptz not null default now(),
  note text not null default '' check (char_length(note) <= 300)
);

create index sightings_journal_idx on public.sightings (cat_id, seen_at desc, id desc);
create index sightings_reported_by_idx on public.sightings (reported_by);
create index cats_created_by_idx on public.cats (created_by);

alter table public.cats enable row level security;
alter table public.sightings enable row level security;

revoke all on public.cats, public.sightings from public, anon, authenticated;
grant select (id, name, description) on public.cats to anon, authenticated;
grant select (id, cat_id, latitude, longitude, seen_at, note)
  on public.sightings to anon, authenticated;
grant insert (name, description) on public.cats to authenticated;
grant insert (cat_id, latitude, longitude, note) on public.sightings to authenticated;

create policy cats_read on public.cats for select to anon, authenticated using (true);
create policy sightings_read on public.sightings for select to anon, authenticated using (true);
create policy cats_insert on public.cats for insert to authenticated
  with check (created_by = (select auth.uid()));
create policy sightings_insert on public.sightings for insert to authenticated
  with check (reported_by = (select auth.uid()));

-- Satu penanda per profil, dari penampakan terakhir yang dilaporkan.
create view public.latest_cat_sightings with (security_invoker = true) as
  select distinct on (s.cat_id)
    s.cat_id, c.name, c.description, s.latitude, s.longitude, s.seen_at
  from public.sightings s
  join public.cats c on c.id = s.cat_id
  order by s.cat_id, s.seen_at desc, s.id desc;

revoke all on public.latest_cat_sightings from public, anon, authenticated;
grant select on public.latest_cat_sightings to anon, authenticated;

-- Profil baru dan penampakan pertamanya disimpan dalam transaksi yang sama.
create function public.add_cat_with_sighting(
  p_name text, p_description text, p_latitude double precision,
  p_longitude double precision, p_note text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_cat_id uuid;
begin
  insert into public.cats (name, description)
  values (btrim(p_name), btrim(p_description)) returning id into new_cat_id;

  insert into public.sightings (cat_id, latitude, longitude, note)
  values (new_cat_id, p_latitude, p_longitude, btrim(p_note));
  return new_cat_id;
end;
$$;

revoke all on function public.add_cat_with_sighting(text, text, double precision, double precision, text)
  from public, anon, authenticated;
grant execute on function public.add_cat_with_sighting(text, text, double precision, double precision, text)
  to authenticated;

-- Bucket disiapkan untuk fitur foto. Akses dari aplikasi dibuka saat unggahan siap.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sighting-photos', 'sighting-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

commit;
