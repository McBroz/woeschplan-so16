-- ============================================================
-- Wöschplan SO 16 — Migration: Wochenwünsche zu Buchungen
-- Wünsche für ganze Jahr eintragen, Admin kann zu Buchungen machen
-- ============================================================

-- Erweitere wp_wishes um calendar_week, year, is_locked
alter table public.wp_wishes
  add column if not exists calendar_week int,
  add column if not exists year int,
  add column if not exists is_locked boolean default false,
  add column if not exists locked_by text;

-- Alte NOT-NULL-Spalten (aus dem Tag/Tageszeit-System) für KW-Wünsche optional machen
alter table public.wp_wishes alter column wish_date drop not null;
alter table public.wp_wishes alter column daypart drop not null;

-- RPC: Admin can lock a wish (user can't edit it anymore)
create or replace function public.wp_lock_wish(
  p_admin_name text, p_admin_pin text, p_wish_id bigint, p_lock boolean
)
returns jsonb language plpgsql security definer as $$
declare v_admin public.wp_users;
begin
  select * into v_admin from public.wp_users where lower(name) = lower(trim(p_admin_name));
  if not found or v_admin.pin <> p_admin_pin or not v_admin.is_admin then
    raise exception 'Kein Admin-Zugriff';
  end if;

  update public.wp_wishes
  set is_locked = p_lock, locked_by = case when p_lock then v_admin.name else null end
  where id = p_wish_id;

  return jsonb_build_object('ok', true);
end; $$;

-- RPC: Admin promotes a wish to actual bookings (creates one 2h slot per day in that week)
create or replace function public.wp_promote_wish_to_booking(
  p_admin_name text, p_admin_pin text, p_wish_id bigint, p_slot_hour int
)
returns jsonb language plpgsql security definer as $$
declare
  v_admin public.wp_users;
  v_wish public.wp_wishes;
  v_week_start timestamptz;
  v_slot_start timestamptz;
  v_slot_end timestamptz;
  v_day_offset int;
begin
  select * into v_admin from public.wp_users where lower(name) = lower(trim(p_admin_name));
  if not found or v_admin.pin <> p_admin_pin or not v_admin.is_admin then
    raise exception 'Kein Admin-Zugriff';
  end if;

  select * into v_wish from public.wp_wishes where id = p_wish_id;
  if not found then
    raise exception 'Wunsch nicht gefunden';
  end if;

  -- Berechne Montag der angegebenen KW im Jahr
  v_week_start := date_trunc('week', make_date(v_wish.year, 1, 4) + ((v_wish.calendar_week - 1) * interval '7 days'))::date::timestamptz;

  -- Buche Montag–Samstag, jeweils den Slot um p_slot_hour (z.B. 09:00–11:00 für p_slot_hour=9)
  for v_day_offset in 0..5 loop
    v_slot_start := v_week_start + (v_day_offset || ' days')::interval + (p_slot_hour || ' hours')::interval;
    v_slot_end := v_slot_start + interval '2 hours';

    -- Prüfe Kollision
    if exists(select 1 from public.wp_bookings where start_ts < v_slot_end and end_ts > v_slot_start) then
      raise exception 'Slot kollidiert mit bestehender Buchung: %', to_char(v_slot_start, 'Mi HH24:00');
    end if;

    -- Buche für Waschmaschine + Tumbler
    insert into public.wp_bookings(user_name, machine, start_ts, end_ts)
    values (v_wish.user_name, 1, v_slot_start, v_slot_end), (v_wish.user_name, 2, v_slot_start, v_slot_end);
  end loop;

  -- Markiere Wunsch als gelöst
  delete from public.wp_wishes where id = p_wish_id;

  return jsonb_build_object('ok', true, 'message', 'Wunsch in Buchungen umgewandelt');
end; $$;

-- RPC: Nutzer trägt einen Wunsch für eine KW ein (RLS blockt direktes Insert)
create or replace function public.wp_add_wish_kw(
  p_name text, p_pin text, p_kw int, p_year int, p_note text
)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  if p_kw < 1 or p_kw > 53 then
    raise exception 'Ungültige Kalenderwoche';
  end if;
  if exists(select 1 from public.wp_wishes where calendar_week = p_kw and year = p_year and is_locked) then
    raise exception 'Diese Woche ist vom Admin gesperrt';
  end if;
  insert into public.wp_wishes(user_name, calendar_week, year, note, created_at)
  values (v_user.name, p_kw, p_year, nullif(trim(p_note), ''), now());
  return jsonb_build_object('ok', true);
end; $$;

-- RPC: Wunsch löschen (eigener, oder Admin); gesperrte nur durch Admin
create or replace function public.wp_del_wish(
  p_name text, p_pin text, p_wish_id bigint
)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users; v_wish public.wp_wishes;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  select * into v_wish from public.wp_wishes where id = p_wish_id;
  if not found then
    raise exception 'Wunsch nicht gefunden';
  end if;
  if lower(v_wish.user_name) <> lower(v_user.name) and not v_user.is_admin then
    raise exception 'Keine Berechtigung';
  end if;
  if v_wish.is_locked and not v_user.is_admin then
    raise exception 'Gesperrte Woche — nur der Admin kann löschen';
  end if;
  delete from public.wp_wishes where id = p_wish_id;
  return jsonb_build_object('ok', true);
end; $$;

-- RPC: Admin bearbeitet die Notiz eines Wunsches
create or replace function public.wp_edit_wish(
  p_admin_name text, p_admin_pin text, p_wish_id bigint, p_note text
)
returns jsonb language plpgsql security definer as $$
declare v_admin public.wp_users;
begin
  select * into v_admin from public.wp_users where lower(name) = lower(trim(p_admin_name));
  if not found or v_admin.pin <> p_admin_pin or not v_admin.is_admin then
    raise exception 'Kein Admin-Zugriff';
  end if;
  update public.wp_wishes set note = nullif(trim(p_note), '') where id = p_wish_id;
  return jsonb_build_object('ok', true);
end; $$;

grant execute on function public.wp_lock_wish(text, text, bigint, boolean) to anon;
grant execute on function public.wp_promote_wish_to_booking(text, text, bigint, int) to anon;
grant execute on function public.wp_add_wish_kw(text, text, int, int, text) to anon;
grant execute on function public.wp_del_wish(text, text, bigint) to anon;
grant execute on function public.wp_edit_wish(text, text, bigint, text) to anon;
