// Edge Function: avisa a outra pessoa (push) quando alguém marca "Recomendo".
// Chamada pelo app depois de mudar o status. Não confia no corpo da chamada:
// confere no banco se o título realmente está como "recomendo" por quem disse,
// e respeita a preferência de aviso de quem recebe.
import { adminClient, corsHeaders, IMG, isEnabled, json, NAMES, sendPush } from '../_shared/push.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const { titleId, from } = await req.json().catch(() => ({}));
  if (!titleId || !(from in NAMES)) return json({ error: 'parâmetros inválidos' }, 400);
  const to = from === 'heitor' ? 'leticia' : 'heitor';

  const supabase = adminClient();

  const { data: title } = await supabase
    .from('titles')
    .select('id, title, poster_path, backdrop_path, status, recommended_by')
    .eq('id', titleId)
    .maybeSingle();

  if (!title || title.status !== 'recomendo' || title.recommended_by !== from) {
    return json({ sent: 0, reason: 'título não está recomendado por essa pessoa' });
  }

  if (!(await isEnabled(supabase, to, 'recommend'))) {
    return json({ sent: 0, reason: 'desativado por quem recebe' });
  }

  return json(await sendPush(supabase, to, {
    title: `${NAMES[from]} recomendou pra você`,
    body: title.title,
    icon: title.poster_path ? `${IMG}/w342${title.poster_path}` : undefined,
    image: title.backdrop_path
      ? `${IMG}/w780${title.backdrop_path}`
      : title.poster_path
      ? `${IMG}/w500${title.poster_path}`
      : undefined,
    tag: `recomendo-${title.id}`,
  }));
});
