-- ============================================================
-- Wöschplan SO 16 — Nachtrag: Wochenplan / Wunschboard
-- Zusätzlich zum ursprünglichen supabase-setup.sql ausführen
-- (baut nicht auf/ersetzt nichts, nur additiv).
-- ============================================================

-- Unverbindliche Wünsche für die kommende Woche — KEINE Reservation,
-- keine Kollisionsprüfung, mehrere Personen können sich denselben
-- Tag/dieselbe Tageszeit wünschen. Dient nur der Übersicht/Absprache.
create table if not exists public.wp_wishes (
  id bigserial primary key,
  user_name text not null,
  wish_date date not null,
  daypart text not null check (daypart in ('morgens','mittags','nachmittags','abends')),
  note text,
  created_at timestamptz not null default now()
);

alter table public.wp_wishes enable row level security;

-- Wie bei Buchungen/Chat: öffentlich lesbar, Schreiben nur über RPC.
create policy "wp_wishes anon select" on public.wp_wishes
  for select to anon using (true);
revoke insert, update, delete on public.wp_wishes from anon;
grant select on public.wp_wishes to anon;

-- Wunsch anmelden: nur für die kommenden 7 Tage, kein Verfalldatum in der Vergangenheit.
create or replace function public.wp_add_wish(
  p_name text, p_pin text, p_date date, p_daypart text, p_note text default null
) returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  if p_date < current_date then
    raise exception 'Datum liegt in der Vergangenheit';
  end if;
  if p_date > current_date + interval '7 days' then
    raise exception 'Wünsche sind nur für die kommenden 7 Tage möglich';
  end if;
  if p_daypart not in ('morgens','mittags','nachmittags','abends') then
    raise exception 'Ungültige Tageszeit';
  end if;
  insert into public.wp_wishes(user_name, wish_date, daypart, note)
  values (v_user.name, p_date, p_daypart, nullif(left(trim(coalesce(p_note,'')),200),''));
  return jsonb_build_object('ok', true);
end; $$;

-- Eigenen Wunsch zurückziehen (oder Admin räumt auf).
create or replace function public.wp_remove_wish(p_name text, p_pin text, p_wish_id bigint)
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
  delete from public.wp_wishes where id = p_wish_id;
  return jsonb_build_object('ok', true);
end; $$;

grant execute on function
  public.wp_add_wish(text, text, date, text, text),
  public.wp_remove_wish(text, text, bigint)
to anon;
