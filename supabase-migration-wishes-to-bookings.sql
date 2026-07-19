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

grant execute on function public.wp_lock_wish(text, text, bigint, boolean) to anon;
grant execute on function public.wp_promote_wish_to_booking(text, text, bigint, int) to anon;
