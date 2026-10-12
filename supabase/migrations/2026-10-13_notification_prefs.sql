-- Rode no SQL Editor do Supabase.

-- Preferências de notificação de cada pessoa. Guarda só o que foi mudado;
-- o que não está aqui usa o padrão definido no app e nas Edge Functions.
create table if not exists public.notification_prefs (
  owner text primary key check (owner in ('heitor', 'leticia')),
  prefs jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.notification_prefs enable row level security;

drop policy if exists "notification_prefs_all_access" on public.notification_prefs;
create policy "notification_prefs_all_access" on public.notification_prefs
  for all using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.notification_prefs;
exception when duplicate_object then null;
end $$;
