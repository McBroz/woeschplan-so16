-- ============================================================
-- Wöschplan SO 16 — Migration: kombinierte Buchung, 3-Tage-Fenster,
-- Hausordnung admin-only, Statistik-Dedupe
-- Einmalig im Supabase SQL Editor ausführen.
-- ============================================================

-- Waschmaschine + Tumbler werden ab jetzt IMMER zusammen für ein Zeitfenster
-- gebucht (ein Klick bucht beide Maschinen-Zeilen). Altes Signature mit
-- p_machine wird entfernt, da nicht mehr gebraucht.
drop function if exists public.wp_create_booking(text, text, int, timestamptz, timestamptz);

create or replace function public.wp_create_booking(
  p_name text, p_pin text, p_start timestamptz, p_end timestamptz
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
  if p_start > now() + interval '4 days' then
    raise exception 'Buchbar nur für heute und die folgenden 3 Tage';
  end if;
  if p_end <= p_start then
    raise exception 'Ungültiger Zeitraum';
  end if;
  if exists (
    select 1 from public.wp_bookings
    where start_ts < p_end and end_ts > p_start
  ) then
    raise exception 'Dieses Zeitfenster ist bereits belegt';
  end if;
  insert into public.wp_bookings(user_name, machine, start_ts, end_ts)
  values (v_user.name, 1, p_start, p_end), (v_user.name, 2, p_start, p_end);
  return jsonb_build_object('ok', true);
end; $$;

-- Stornieren: löscht jetzt BEIDE Maschinen-Zeilen des Zeitfensters (Waschmaschine
-- + Tumbler gehören zusammen), nicht nur die eine Zeile hinter der übergebenen id.
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
  delete from public.wp_bookings
  where user_name = v_booking.user_name and start_ts = v_booking.start_ts and end_ts = v_booking.end_ts;
  return jsonb_build_object('ok', true);
end; $$;

grant execute on function public.wp_create_booking(text, text, timestamptz, timestamptz) to anon;

-- Hausordnung: nur Admin darf posten (Blackboard statt Chat). Löschen bleibt
-- über wp_admin_action(action='delete_chat') beim Admin.
create or replace function public.wp_send_chat(p_name text, p_pin text, p_msg text)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  if not v_user.is_admin then
    raise exception 'Nur der Admin kann hier neue Einträge anschlagen';
  end if;
  if p_msg is null or length(trim(p_msg)) = 0 then
    raise exception 'Leere Nachricht';
  end if;
  insert into public.wp_chat_messages(name, msg) values (v_user.name, left(trim(p_msg), 500));
  return jsonb_build_object('ok', true);
end; $$;

-- Statistik: Buchungen zählen jetzt pro Zeitfenster (nicht pro Maschinen-Zeile),
-- sonst würde jede Buchung doppelt gezählt (Waschmaschine + Tumbler = 2 Zeilen).
create or replace function public.wp_admin_stats(p_admin_name text, p_admin_pin text)
returns table(
  name text,
  apartment text,
  bookings_count bigint,
  total_hours numeric,
  wishes_count bigint,
  last_active timestamptz
)
language plpgsql security definer as $$
declare v_admin public.wp_users;
begin
  select * into v_admin from public.wp_users wu where lower(wu.name) = lower(trim(p_admin_name));
  if not found or v_admin.pin <> p_admin_pin or not v_admin.is_admin then
    raise exception 'Kein Admin-Zugriff';
  end if;

  return query
  select
    u.name,
    u.apartment,
    coalesce(bk.cnt, 0) as bookings_count,
    coalesce(round(bk.hours, 1), 0) as total_hours,
    coalesce(wk.cnt, 0) as wishes_count,
    greatest(bk.last_ts, wk.last_ts) as last_active
  from public.wp_users u
  left join (
    select user_name,
           count(*) as cnt,
           sum(extract(epoch from (end_ts - start_ts)) / 3600.0) as hours,
           max(start_ts) as last_ts
    from (select distinct user_name, start_ts, end_ts from public.wp_bookings) slots
    group by user_name
  ) bk on lower(bk.user_name) = lower(u.name)
  left join (
    select user_name, count(*) as cnt, max(created_at) as last_ts
    from public.wp_wishes
    group by user_name
  ) wk on lower(wk.user_name) = lower(u.name)
  order by 3 desc, 4 desc, 1 asc;
end; $$;

grant execute on function public.wp_admin_stats(text, text) to anon;
