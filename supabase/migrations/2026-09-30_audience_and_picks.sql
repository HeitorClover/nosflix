-- Rode no SQL Editor do Supabase (só quem já criou o schema antes).

-- Para quem é o título: "juntos", só o Heitor ou só a Leticia.
-- Vale para "quero ver" (lista de desejos) e para "assistindo" (quem está assistindo).
alter table public.titles
  add column if not exists audience text not null default 'juntos'
  check (audience in ('juntos', 'heitor', 'leticia'));

-- Votação da noite de cinema: cada pessoa escolhe até 3 títulos.
create table if not exists public.picks (
  id uuid primary key default gen_random_uuid(),
  owner text not null check (owner in ('heitor', 'leticia')),
  title_id uuid not null references public.titles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (owner, title_id)
);

create index if not exists picks_title_idx on public.picks (title_id);

alter table public.picks enable row level security;

drop policy if exists "picks_all_access" on public.picks;
create policy "picks_all_access" on public.picks
  for all using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.picks;
exception when duplicate_object then null;
end $$;
