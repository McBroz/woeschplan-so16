-- ============================================================
-- Wöschplan SO 16 — Supabase Setup
-- Führe dieses komplette Skript einmal im Supabase SQL Editor aus
-- (Projekt: dasselbe wie beim WM-Tippspiel, tjrybgrdjvntdbjdlyio)
-- ============================================================

-- ─── Tabellen ───────────────────────────────────────────────

create table if not exists public.wp_users (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  pin text not null,
  apartment text,
  is_admin boolean not null default false,
  blocked boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.wp_bookings (
  id bigserial primary key,
  user_name text not null,
  machine int not null check (machine in (1,2)),
  start_ts timestamptz not null,
  end_ts timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.wp_chat_messages (
  id bigserial primary key,
  name text not null,
  msg text not null,
  created_at timestamptz not null default now()
);

-- ─── Row Level Security ─────────────────────────────────────
-- Prinzip: Der Anon-Key darf NUR lesen (SELECT). Jedes Schreiben
-- (Login, Registrierung, Buchen, Chat, Admin-Aktionen) läuft über
-- die unten definierten RPC-Funktionen (security definer), die
-- Name+PIN serverseitig prüfen. So kann niemand mit dem öffentlich
-- sichtbaren Anon-Key fremde Buchungen ändern oder PINs auslesen
-- (Verbesserung gegenüber dem Tippspiel-Setup).

alter table public.wp_users enable row level security;
alter table public.wp_bookings enable row level security;
alter table public.wp_chat_messages enable row level security;

-- Kein direktes SELECT auf wp_users für anon (enthält PINs) —
-- Nutzerliste ohne PIN kommt über die Funktion wp_public_users().
revoke all on public.wp_users from anon;

-- Buchungen & Chat sind unter den Hausbewohnern nicht geheim.
create policy "wp_bookings anon select" on public.wp_bookings
  for select to anon using (true);
create policy "wp_chat anon select" on public.wp_chat_messages
  for select to anon using (true);

revoke insert, update, delete on public.wp_bookings from anon;
revoke insert, update, delete on public.wp_chat_messages from anon;
grant select on public.wp_bookings to anon;
grant select on public.wp_chat_messages to anon;

-- ─── RPC-Funktionen (security definer = laufen mit erhöhten Rechten,
--      umgehen RLS, prüfen aber selbst Name/PIN/Admin-Rechte) ───

-- Registrierung: neuer Nutzer wählt PIN. Max. 12 Personen im Haus.
create or replace function public.wp_register(p_name text, p_pin text, p_apartment text default null)
returns jsonb language plpgsql security definer as $$
declare v_count int;
begin
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Name fehlt';
  end if;
  if p_pin is null or length(p_pin) <> 4 or p_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN muss 4 Ziffern haben';
  end if;
  if exists (select 1 from public.wp_users where lower(name) = lower(trim(p_name))) then
    raise exception 'Name bereits vergeben';
  end if;
  select count(*) into v_count from public.wp_users;
  if v_count >= 12 then
    raise exception 'Haus ist voll (max. 12 Personen)';
  end if;
  insert into public.wp_users(name, pin, apartment) values (trim(p_name), p_pin, p_apartment);
  return jsonb_build_object('ok', true, 'is_admin', false);
end; $$;

-- Login: prüft Name+PIN, gibt is_admin/blocked zurück (kein PIN im Ergebnis).
create or replace function public.wp_login(p_name text, p_pin text)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_user.pin <> p_pin then
    return jsonb_build_object('ok', false, 'reason', 'wrong_pin');
  end if;
  return jsonb_build_object('ok', true, 'is_admin', v_user.is_admin, 'blocked', v_user.blocked, 'name', v_user.name);
end; $$;

-- Prüft ob ein Name existiert (für den 2-Schritt-Login, ohne PIN preiszugeben).
create or replace function public.wp_check_name(p_name text)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found then
    return jsonb_build_object('exists', false);
  end if;
  return jsonb_build_object('exists', true, 'is_admin', v_user.is_admin);
end; $$;

-- Öffentliche Nutzerliste ohne PIN (für Kalender-Anzeige "wer hat gebucht" etc).
create or replace function public.wp_public_users()
returns table(name text, apartment text, is_admin boolean, blocked boolean)
language sql security definer as $$
  select name, apartment, is_admin, blocked from public.wp_users order by created_at;
$$;

-- Buchung erstellen: buchbar für heute + die folgenden 2 Tage (rollierendes
-- 72h-Fenster, zeitzonensicher), kein Überlappen auf derselben Maschine.
create or replace function public.wp_create_booking(
  p_name text, p_pin text, p_machine int, p_start timestamptz, p_end timestamptz
) returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  if p_end <= now() then
    raise exception 'Dieser Zeitraum ist bereits vorbei';
  end if;
  if p_start > now() + interval '3 days' then
    raise exception 'Buchbar nur für heute und die folgenden 2 Tage';
  end if;
  if p_end <= p_start then
    raise exception 'Ungültiger Zeitraum';
  end if;
  if exists (
    select 1 from public.wp_bookings
    where machine = p_machine and start_ts < p_end and end_ts > p_start
  ) then
    raise exception 'Diese Maschine ist in diesem Zeitfenster bereits belegt';
  end if;
  insert into public.wp_bookings(user_name, machine, start_ts, end_ts)
  values (v_user.name, p_machine, p_start, p_end);
  return jsonb_build_object('ok', true);
end; $$;

-- Buchung stornieren: eigene Buchung, oder Admin.
create or replace function public.wp_cancel_booking(p_name text, p_pin text, p_booking_id bigint)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users; v_booking public.wp_bookings;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  select * into v_booking from public.wp_bookings where id = p_booking_id;
  if not found then
    raise exception 'Buchung nicht gefunden';
  end if;
  if lower(v_booking.user_name) <> lower(v_user.name) and not v_user.is_admin then
    raise exception 'Keine Berechtigung';
  end if;
  delete from public.wp_bookings where id = p_booking_id;
  return jsonb_build_object('ok', true);
end; $$;

-- Chat senden: gesperrte Nutzer können nicht schreiben.
create or replace function public.wp_send_chat(p_name text, p_pin text, p_msg text)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  if v_user.blocked then
    raise exception 'Du bist für den Chat gesperrt';
  end if;
  if p_msg is null or length(trim(p_msg)) = 0 then
    raise exception 'Leere Nachricht';
  end if;
  insert into public.wp_chat_messages(name, msg) values (v_user.name, left(trim(p_msg), 500));
  return jsonb_build_object('ok', true);
end; $$;

-- Admin-Aktionen: Nutzerliste MIT PIN, Sperren/Entsperren, PIN-Reset,
-- Nutzer löschen, Chat-Nachricht löschen — alles nur mit gültigem Admin-Login.
create or replace function public.wp_admin_action(
  p_admin_name text, p_admin_pin text, p_action text,
  p_target_name text default null, p_new_pin text default null,
  p_msg_id bigint default null
) returns jsonb language plpgsql security definer as $$
declare v_admin public.wp_users;
begin
  select * into v_admin from public.wp_users where lower(name) = lower(trim(p_admin_name));
  if not found or v_admin.pin <> p_admin_pin or not v_admin.is_admin then
    raise exception 'Kein Admin-Zugriff';
  end if;

  if p_action = 'list_users' then
    return (
      select jsonb_agg(jsonb_build_object(
        'name', u.name, 'pin', u.pin, 'apartment', u.apartment,
        'is_admin', u.is_admin, 'blocked', u.blocked, 'created_at', u.created_at
      ) order by u.created_at)
      from public.wp_users u
    );
  elsif p_action = 'toggle_block' then
    update public.wp_users set blocked = not blocked where lower(name) = lower(p_target_name);
    return jsonb_build_object('ok', true);
  elsif p_action = 'reset_pin' then
    if p_new_pin is null or length(p_new_pin) <> 4 or p_new_pin !~ '^[0-9]{4}$' then
      raise exception 'PIN muss 4 Ziffern haben';
    end if;
    update public.wp_users set pin = p_new_pin where lower(name) = lower(p_target_name);
    return jsonb_build_object('ok', true);
  elsif p_action = 'delete_user' then
    delete from public.wp_users where lower(name) = lower(p_target_name) and is_admin = false;
    return jsonb_build_object('ok', true);
  elsif p_action = 'delete_chat' then
    delete from public.wp_chat_messages where id = p_msg_id;
    return jsonb_build_object('ok', true);
  else
    raise exception 'Unbekannte Aktion';
  end if;
end; $$;

-- ─── Rechte für die RPC-Funktionen ───────────────────────────
grant execute on function
  public.wp_register(text, text, text),
  public.wp_login(text, text),
  public.wp_check_name(text),
  public.wp_public_users(),
  public.wp_create_booking(text, text, int, timestamptz, timestamptz),
  public.wp_cancel_booking(text, text, bigint),
  public.wp_send_chat(text, text, text),
  public.wp_admin_action(text, text, text, text, text, bigint)
to anon;

-- ─── Admin-Konto anlegen (einmalig) ──────────────────────────
insert into public.wp_users (name, pin, is_admin)
values ('Ale', '8134', true)
on conflict (name) do update set pin = excluded.pin, is_admin = true;

-- ─── Realtime (optional, für Live-Chat-Updates) ──────────────
-- In Supabase Dashboard → Database → Replication kann man
-- wp_chat_messages und wp_bookings für Realtime aktivieren,
-- ist aber nicht zwingend (App pollt alle paar Sekunden).
