# Nosflix

App do casal pra catalogar filmes, séries, desenhos e animes: o que já assistiram juntos,
o que um recomenda pro outro, o que estão assistindo e o que querem ver.

- **Heitor** roda via `flutter build apk --release` (Android, tema vermelho)
- **Leticia** roda via `flutter build web --release` (PWA, tema rosa)
- Também roda nativo no **Windows** via `flutter build windows --release`
- Banco de dados: **Supabase** (Postgres)
- Catálogo/pôsteres: **TMDB** (The Movie Database)

## 1. Configurar o Supabase

1. Crie um projeto em [supabase.com](https://supabase.com) (free tier é suficiente).
2. Vá em **SQL Editor** e rode o conteúdo de [`supabase/schema.sql`](supabase/schema.sql).
   Isso cria as tabelas `titles` e `ratings`, os índices, triggers e as políticas de RLS.
3. Vá em **Project Settings > API** e copie:
   - **Project URL** → `SUPABASE_URL`
   - **anon / public key** (ou "publishable key") → `SUPABASE_ANON_KEY`

## 2. Configurar a TMDB

1. Crie uma conta em [themoviedb.org](https://www.themoviedb.org/) e gere uma API key em
   **Settings > API** (é gratuita).
2. Copie a **API Key (v3 auth)** → `TMDB_API_KEY`.

## 3. Preencher o `.env`

Copie `.env.example` para `.env` (já existe um `.env` placeholder no projeto — só
preencher os valores reais) e preencha:

```
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=sua-anon-key
TMDB_API_KEY=sua-tmdb-key
```

> O `.env` está no `.gitignore` — nunca vai pro git. Mas atenção: como o app não usa login
> real (só um seletor de perfil Heitor/Leticia local), a anon key fica embutida no
> binário/bundle final. Isso é aceitável pra um app privado entre vocês dois, mas não
> distribua o APK/link publicamente.

## 4. Rodar em desenvolvimento

```
flutter pub get
flutter run
```

## 5. Builds de produção

**Android (Heitor):**
```
flutter build apk --release
```
O APK fica em `build/app/outputs/flutter-apk/app-release.apk`.

**Web / PWA (Leticia):**
```
flutter build web --release
```
O bundle fica em `build/web` — suba em qualquer hospedagem estática (Vercel, Netlify,
GitHub Pages, Firebase Hosting...). Já sai com `manifest.json` e service worker
configurados, então dá pra "instalar" como app no celular/desktop pelo navegador.

**Windows (nativo):**
```
flutter build windows --release
```
O executável fica em `build/windows/x64/runner/Release/nosflix.exe` (junto com as DLLs
da pasta — precisa levar a pasta inteira, não só o `.exe`). Útil pra testar/rodar no seu
PC sem precisar abrir o navegador.

## Como funciona

- Na primeira vez que abre o app, escolhe o perfil (Heitor ou Leticia). O app já sugere
  o perfil mais provável com base na plataforma (Android → Heitor, Web → Leticia), mas
  dá pra escolher o outro manualmente.
- Pra adicionar um título, busca por nome (via TMDB) e escolhe a categoria (filme, série,
  desenho, anime, documentário...).
- Cada título tem um **status compartilhado**: Temos que ver juntos / Assistindo / Já vimos juntos /
  Recomendo (quando um dos dois assistiu sozinho e quer indicar pro outro).
- Cada pessoa pode dar sua **nota, comentário e data** que assistiu, independente da nota
  do outro — dá pra ver os dois lados na tela de detalhe do título.

## Deploy no Vercel (web/PWA)

O projeto já tem `vercel.json` + `vercel_build.sh` configurados pra instalar o Flutter
na build da Vercel (a imagem padrão deles não vem com Flutter) e gerar o `.env` a partir
de variáveis de ambiente do projeto na Vercel.

1. Em [vercel.com](https://vercel.com), **Add New > Project** e importe o repositório
   `nosflix` do GitHub.
2. Em **Environment Variables**, adicione (mesmos valores do seu `.env` local):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `TMDB_API_KEY`
3. Não precisa mexer em Build Command / Output Directory — já vêm do `vercel.json`.
4. Deploy. A cada `git push` na branch principal, a Vercel builda e publica sozinha.

## Ideias futuras (não implementadas)

- Import de CSV exportado do "Atividade de visualização" da Netflix pra bulk-import do
  histórico (a Netflix não tem API pública, só exportação manual em Conta > Perfil >
  Atividade de visualização > Baixar tudo).
- Notificações push quando o outro adiciona/recomenda um título.
- Modo "sorteio" pra decidir o que assistir quando tiver muita coisa na fila.
