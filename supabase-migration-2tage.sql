-- ============================================================
-- Wöschplan SO 16 — Migration: Buchungsfenster auf "heute + 2 Tage"
-- Ersetzt die 5-Stunden-Regel in wp_create_booking.
-- Einmalig im Supabase SQL Editor ausführen (nur diese eine Funktion).
-- ============================================================

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
