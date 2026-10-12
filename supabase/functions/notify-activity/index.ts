// Edge Function: avisa a outra pessoa (push) sobre atividade em séries.
//   kind "progress": alguém avançou um episódio de uma série que assiste sozinho
//                    ("Heitor viu T2 · E4 de X sem você").
//   kind "comment":  alguém comentou um episódio (o texto NÃO vai na notificação,
//                    pra não dar spoiler).
// Não confia no corpo da chamada: confere no banco antes de enviar.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const NAMES: Record<string, string> = { heitor: 'Heitor', leticia: 'Leticia' };
const IMG = 'https://image.tmdb.org/t/p';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const { kind, titleId, from, season, episode } = await req.json().catch(() => ({}));
  if (!titleId || !(from in NAMES) || !['progress', 'comment'].includes(kind)) {
    return json({ error: 'parâmetros inválidos' }, 400);
  }
  const to = from === 'heitor' ? 'leticia' : 'heitor';

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: title } = await supabase
    .from('titles')
    .select('id, title, poster_path, backdrop_path, status, audience, current_season, current_episode')
    .eq('id', titleId)
    .maybeSingle();
  if (!title) return json({ sent: 0, reason: 'título não existe' });

  let heading: string;
  let body: string;
  let tag: string;

  if (kind === 'progress') {
    // Só faz sentido avisar quando a pessoa assiste sozinha.
    if (title.status !== 'assistindo' || title.audience !== from) {
      return json({ sent: 0, reason: 'não está assistindo sozinho(a)' });
    }
    const s = title.current_season ?? 1;
    const e = title.current_episode ?? 1;
    heading = `${NAMES[from]} viu T${s} · E${e} sem você`;
    body = title.title;
    tag = `progress-${title.id}`;
  } else {
    const { data: comment } = await supabase
      .from('episode_comments')
      .select('id')
      .eq('title_id', titleId)
      .eq('owner', from)
      .eq('season', season)
      .eq('episode', episode)
      .maybeSingle();
    if (!comment) return json({ sent: 0, reason: 'comentário não existe' });
    heading = `${NAMES[from]} comentou T${season} · E${episode}`;
    body = title.title;
    tag = `comment-${title.id}-${season}-${episode}`;
  }

  const { data: subs } = await supabase
    .from('push_subscriptions')
    .select('id, endpoint, p256dh, auth')
    .eq('owner', to);
  if (!subs || subs.length === 0) return json({ sent: 0, reason: 'sem inscrições' });

  webpush.setVapidDetails(
    Deno.env.get('VAPID_SUBJECT')!,
    Deno.env.get('VAPID_PUBLIC_KEY')!,
    Deno.env.get('VAPID_PRIVATE_KEY')!,
  );

  const payload = JSON.stringify({
    title: heading,
    body,
    icon: title.poster_path ? `${IMG}/w342${title.poster_path}` : undefined,
    image: title.backdrop_path ? `${IMG}/w780${title.backdrop_path}` : undefined,
    url: '/',
    tag,
  });

  let sent = 0;
  await Promise.all(subs.map(async (s) => {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        payload,
      );
      sent++;
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) {
        await supabase.from('push_subscriptions').delete().eq('id', s.id);
      } else {
        console.error('falha ao enviar push', code, e);
      }
    }
  }));

  return json({ sent });
});
