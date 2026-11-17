-- HelpUs account, vehicle, tag, and alert schema for Supabase.
-- Run this once in the Supabase SQL Editor before enabling phone sign-in.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text not null unique,
  display_name text not null default '',
  locale text not null default 'en',
  keep_phone_private boolean not null default true,
  allow_parking_alerts boolean not null default true,
  show_vehicle_details boolean not null default true,
  share_location boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vehicle_tags (
  tag_code text primary key check (tag_code = upper(tag_code)),
  claimed_by uuid references auth.users(id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  tag_code text not null unique references public.vehicle_tags(tag_code),
  vehicle_type text not null default 'car' check (vehicle_type in ('car','motorcycle','scooter','other')),
  make_model text not null,
  registration_number text not null,
  model_year integer check (model_year is null or model_year between 1950 and 2100),
  color text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(owner_id, registration_number)
);

create table if not exists public.scan_alerts (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  event_type text not null check (event_type in ('scan','parking','lights','other')),
  message text not null default '',
  city text not null default '',
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.profiles enable row level security;
alter table public.vehicle_tags enable row level security;
alter table public.vehicles enable row level security;
alter table public.scan_alerts enable row level security;

drop policy if exists "Owners read their profile" on public.profiles;
create policy "Owners read their profile" on public.profiles for select using ((select auth.uid()) = id);
drop policy if exists "Owners update their profile" on public.profiles;
create policy "Owners update their profile" on public.profiles for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists "Owners read their vehicles" on public.vehicles;
create policy "Owners read their vehicles" on public.vehicles for select using ((select auth.uid()) = owner_id);
drop policy if exists "Owners update their vehicles" on public.vehicles;
create policy "Owners update their vehicles" on public.vehicles for update using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists "Owners delete their vehicles" on public.vehicles;
create policy "Owners delete their vehicles" on public.vehicles for delete using ((select auth.uid()) = owner_id);

drop policy if exists "Owners read alerts for their vehicles" on public.scan_alerts;
create policy "Owners read alerts for their vehicles" on public.scan_alerts for select using (
  exists (select 1 from public.vehicles v where v.id = vehicle_id and v.owner_id = (select auth.uid()))
);
drop policy if exists "Owners mark their alerts read" on public.scan_alerts;
create policy "Owners mark their alerts read" on public.scan_alerts for update using (
  exists (select 1 from public.vehicles v where v.id = vehicle_id and v.owner_id = (select auth.uid()))
) with check (
  exists (select 1 from public.vehicles v where v.id = vehicle_id and v.owner_id = (select auth.uid()))
);

revoke all on public.vehicle_tags from anon, authenticated;
revoke insert, update, delete on public.vehicles from anon, authenticated;
revoke insert, update, delete on public.profiles from anon, authenticated;
revoke insert, update, delete on public.scan_alerts from anon, authenticated;

create or replace function public.register_vehicle(
  p_tag_code text,
  p_make_model text,
  p_registration_number text,
  p_vehicle_type text default 'car',
  p_model_year integer default null,
  p_color text default ''
)
returns public.vehicles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_vehicle public.vehicles;
  v_tag text := upper(trim(p_tag_code));
begin
  if auth.uid() is null then
    raise exception 'Sign in before registering a vehicle.' using errcode = '28000';
  end if;
  if length(trim(p_make_model)) < 2 or length(trim(p_registration_number)) < 4 then
    raise exception 'Enter a valid vehicle model and registration number.' using errcode = '22023';
  end if;
  update public.vehicle_tags
    set claimed_by = auth.uid(), claimed_at = now()
    where tag_code = v_tag and claimed_by is null;
  if not found then
    raise exception 'This HelpUs tag is not available or has already been registered.' using errcode = '23505';
  end if;
  insert into public.vehicles (owner_id, tag_code, vehicle_type, make_model, registration_number, model_year, color)
    values (auth.uid(), v_tag, p_vehicle_type, trim(p_make_model), upper(trim(p_registration_number)), p_model_year, trim(coalesce(p_color, '')))
    returning * into v_vehicle;
  return v_vehicle;
end;
$$;

revoke all on function public.register_vehicle(text,text,text,text,integer,text) from public;
grant execute on function public.register_vehicle(text,text,text,text,integer,text) to authenticated;
grant select, delete on public.vehicles to authenticated;
grant update (vehicle_type, make_model, registration_number, model_year, color, is_active) on public.vehicles to authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, locale, keep_phone_private, allow_parking_alerts, show_vehicle_details, share_location, updated_at) on public.profiles to authenticated;
grant select on public.scan_alerts to authenticated;
grant update (read_at) on public.scan_alerts to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, phone, display_name)
  values (new.id, coalesce(new.phone, ''), coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do update set phone = excluded.phone;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
