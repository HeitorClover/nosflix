// Edge Function: avisa a outra pessoa (push) quando alguém marca "Recomendo".
// Chamada pelo app depois de mudar o status. Não confia no corpo da chamada:
// confere no banco se o título realmente está como "recomendo" por quem disse.
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

  const { titleId, from } = await req.json().catch(() => ({}));
  if (!titleId || !(from in NAMES)) return json({ error: 'parâmetros inválidos' }, 400);
  const to = from === 'heitor' ? 'leticia' : 'heitor';

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: title } = await supabase
    .from('titles')
    .select('id, title, poster_path, backdrop_path, status, recommended_by')
    .eq('id', titleId)
    .maybeSingle();

  if (!title || title.status !== 'recomendo' || title.recommended_by !== from) {
    return json({ sent: 0, reason: 'título não está recomendado por essa pessoa' });
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
    title: `${NAMES[from]} recomendou pra você`,
    body: title.title,
    icon: title.poster_path ? `${IMG}/w342${title.poster_path}` : undefined,
    image: title.backdrop_path
      ? `${IMG}/w780${title.backdrop_path}`
      : title.poster_path
      ? `${IMG}/w500${title.poster_path}`
      : undefined,
    url: '/',
    tag: `recomendo-${title.id}`,
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
      // 404/410 = inscrição não existe mais (app desinstalado, permissão revogada).
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
