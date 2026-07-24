-- ============================================================
-- Wöschplan SO 16 — Migration: Waschraum-Füllstand
-- Beim Buchen (oder jederzeit) meldet man kurz, wie voll der
-- Waschraum gerade ist (0–100 %). Der letzte Eintrag ist der
-- aktuelle Stand und wird allen grafisch angezeigt.
-- ============================================================

create table if not exists public.wp_room_status (
  id bigserial primary key,
  user_name text not null,
  level int not null check (level >= 0 and level <= 100),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists wp_room_status_created_idx
  on public.wp_room_status (created_at desc);

-- RLS: lesen darf jeder im Haus, schreiben nur über die RPC unten
alter table public.wp_room_status enable row level security;

drop policy if exists "wp_room_status anon select" on public.wp_room_status;
create policy "wp_room_status anon select" on public.wp_room_status
  for select to anon using (true);

revoke insert, update, delete on public.wp_room_status from anon;
grant select on public.wp_room_status to anon;

-- RPC: Füllstand melden (Name + PIN werden serverseitig geprüft)
create or replace function public.wp_set_room_status(
  p_name text, p_pin text, p_level int, p_note text default null
)
returns jsonb language plpgsql security definer as $$
declare v_user public.wp_users;
begin
  select * into v_user from public.wp_users where lower(name) = lower(trim(p_name));
  if not found or v_user.pin <> p_pin then
    raise exception 'Login ungültig';
  end if;
  if p_level is null or p_level < 0 or p_level > 100 then
    raise exception 'Füllstand muss zwischen 0 und 100 liegen';
  end if;

  insert into public.wp_room_status(user_name, level, note)
  values (v_user.name, p_level, nullif(trim(p_note), ''));

  -- Historie schlank halten: nur die letzten 200 Meldungen behalten
  delete from public.wp_room_status
  where id in (
    select id from public.wp_room_status order by created_at desc offset 200
  );

  return jsonb_build_object('ok', true, 'level', p_level);
end; $$;

grant execute on function public.wp_set_room_status(text, text, int, text) to anon;
