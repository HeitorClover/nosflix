-- Nosflix — schema Supabase
-- Rode este script no SQL Editor do seu projeto Supabase (Project > SQL Editor > New query).

create extension if not exists "pgcrypto";

-- ============================================================
-- titles: catálogo de filmes/séries/desenhos que vocês cadastram
-- ============================================================
create table if not exists public.titles (
  id uuid primary key default gen_random_uuid(),

  -- dados vindos da TMDB (ou preenchidos manualmente)
  tmdb_id integer,
  media_type text not null check (media_type in ('movie', 'tv')),
  category text not null default 'filme' check (category in ('filme', 'serie', 'desenho', 'anime', 'documentario', 'outro')),
  title text not null,
  original_title text,
  poster_path text,
  backdrop_path text,
  overview text,
  release_year integer,
  genres text[] default '{}',

  -- status compartilhado do casal para este título
  status text not null default 'quero_ver'
    check (status in ('quero_ver', 'assistindo', 'assistido_juntos', 'recomendo')),

  -- progresso de séries (usado quando status = 'assistindo')
  current_season integer,
  current_episode integer,

  -- para quem é: 'juntos' ou só um dos dois (lista de desejos / quem está assistindo)
  audience text not null default 'juntos' check (audience in ('juntos', 'heitor', 'leticia')),

  -- só usado quando status = 'recomendo' (quem assistiu sozinho e tá indicando)
  recommended_by text check (recommended_by in ('heitor', 'leticia')),

  added_by text not null check (added_by in ('heitor', 'leticia')),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists titles_status_idx on public.titles (status);
create index if not exists titles_tmdb_idx on public.titles (tmdb_id, media_type);

-- ============================================================
-- ratings: avaliação individual (nota, comentário, data assistida)
-- um registro por pessoa por título
-- ============================================================
create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  title_id uuid not null references public.titles (id) on delete cascade,
  owner text not null check (owner in ('heitor', 'leticia')),

  rating numeric(3, 1) check (rating >= 0 and rating <= 10),
  comment text,
  watched_at date,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (title_id, owner)
);

create index if not exists ratings_title_idx on public.ratings (title_id);

-- ============================================================
-- push_subscriptions: aparelhos que aceitaram receber notificações
-- (um por aparelho/navegador; "owner" é o perfil logado nele)
-- ============================================================
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner text not null check (owner in ('heitor', 'leticia')),
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

create index if not exists push_subscriptions_owner_idx on public.push_subscriptions (owner);

-- ============================================================
-- trigger para manter updated_at em dia
-- ============================================================
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists titles_set_updated_at on public.titles;
create trigger titles_set_updated_at
  before update on public.titles
  for each row execute function public.set_updated_at();

drop trigger if exists ratings_set_updated_at on public.ratings;
create trigger ratings_set_updated_at
  before update on public.ratings
  for each row execute function public.set_updated_at();

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

-- ============================================================
-- picks: votação da noite de cinema (cada pessoa escolhe até 3 títulos)
-- ============================================================
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

-- ============================================================
-- main_titles: série principal de cada pessoa (entre as que está assistindo)
-- ============================================================
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

-- ============================================================
-- notification_prefs: o que cada pessoa quer receber (só o que foi mudado;
-- o resto usa o padrão do app e das Edge Functions)
-- ============================================================
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

-- ============================================================
-- Row Level Security
-- Este app não usa Supabase Auth (é só vocês dois, com um seletor
-- de perfil local no app). A anon key fica embutida no build, então
-- liberamos acesso total para o papel "anon". Não deixe o link/apk
-- público além de vocês dois.
-- ============================================================
alter table public.titles enable row level security;
alter table public.ratings enable row level security;
alter table public.push_subscriptions enable row level security;

drop policy if exists "push_subscriptions_all_access" on public.push_subscriptions;
create policy "push_subscriptions_all_access" on public.push_subscriptions
  for all using (true) with check (true);

drop policy if exists "titles_all_access" on public.titles;
create policy "titles_all_access" on public.titles
  for all using (true) with check (true);

drop policy if exists "ratings_all_access" on public.ratings;
create policy "ratings_all_access" on public.ratings
  for all using (true) with check (true);

-- ============================================================
-- Realtime (opcional, mas útil pra ver na hora quando um dos dois
-- adiciona/atualiza um título)
-- ============================================================
alter publication supabase_realtime add table public.titles;
alter publication supabase_realtime add table public.ratings;
