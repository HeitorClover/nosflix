-- Rode no SQL Editor do Supabase (só quem já criou o schema antes).

-- ============================================================
-- episode_comments: comentário por episódio (séries, desenhos, animes)
-- um registro por pessoa por episódio
-- ============================================================
create table if not exists public.episode_comments (
  id uuid primary key default gen_random_uuid(),
  title_id uuid not null references public.titles (id) on delete cascade,
  owner text not null check (owner in ('heitor', 'leticia')),
  season integer not null check (season >= 0),
  episode integer not null check (episode >= 1),
  comment text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (title_id, owner, season, episode)
);

create index if not exists episode_comments_title_idx on public.episode_comments (title_id);

drop trigger if exists episode_comments_set_updated_at on public.episode_comments;
create trigger episode_comments_set_updated_at
  before update on public.episode_comments
  for each row execute function public.set_updated_at();

alter table public.episode_comments enable row level security;

drop policy if exists "episode_comments_all_access" on public.episode_comments;
create policy "episode_comments_all_access" on public.episode_comments
  for all using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.episode_comments;
exception when duplicate_object then null;
end $$;

