-- ============================================================
-- Wöschplan SO 16 — Migration: Admin-Statistik
-- Wer wäscht wie viel? Zeigt pro Nutzer Buchungen, Stunden,
-- Wunschboard-Einträge und letzte Aktivität.
-- Einmalig im Supabase SQL Editor ausführen (additiv, kein Datenverlust).
-- ============================================================

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
    from public.wp_bookings
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
