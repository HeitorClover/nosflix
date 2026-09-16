#!/usr/bin/env bash
set -euo pipefail

# Instala o Flutter SDK (a imagem de build da Vercel não vem com ele).
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter config --enable-web

# As chaves ficam como Environment Variables no painel da Vercel
# (Project Settings > Environment Variables), não commitadas no repo.
# Aqui geramos o .env que o app lê via flutter_dotenv em tempo de execução.
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
TMDB_API_KEY=${TMDB_API_KEY:-}
EOF

flutter pub get
flutter build web --release
