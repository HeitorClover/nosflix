-- Rode no SQL Editor do Supabase.

-- Série principal de cada pessoa (entre as que está assistindo). Uma por pessoa.
create table if not exists public.main_titles (
  id uuid primary key default gen_random_uuid(),
  owner text not null unique check (owner in ('heitor', 'leticia')),
  title_id uuid not null references public.titles (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.main_titles enable row level security;

drop policy if exists "main_titles_all_access" on public.main_titles;
create policy "main_titles_all_access" on public.main_titles
  for all using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.main_titles;
exception when duplicate_object then null;
end $$;
