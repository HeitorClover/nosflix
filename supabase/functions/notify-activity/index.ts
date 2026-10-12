// Edge Function: avisa a outra pessoa (push) sobre atividade no app.
//   progress        alguém avançou um episódio de uma série que assiste sozinho(a)
//   comment         alguém comentou um episódio (o texto NÃO vai na notificação)
//   series_comment  alguém comentou uma obra (idem, sem o texto)
//   title_added     alguém adicionou uma obra ao catálogo
//   draw            alguém sorteou o que vão ver
//   pick            alguém escolheu um título na votação da noite de cinema
//   main            alguém definiu/mudou a série principal
// Não confia no corpo da chamada: confere no banco antes de enviar, e só envia
// se quem recebe não tiver desligado esse tipo de aviso.
import { adminClient, corsHeaders, IMG, isEnabled, json, NAMES, sendPush } from '../_shared/push.ts';

const KINDS = ['progress', 'comment', 'series_comment', 'title_added', 'draw', 'pick', 'main'];
const RECENT_MS = 15 * 60 * 1000;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const { kind, titleId, from, season, episode } = await req.json().catch(() => ({}));
  if (!titleId || !(from in NAMES) || !KINDS.includes(kind)) {
    return json({ error: 'parâmetros inválidos' }, 400);
  }
  const to = from === 'heitor' ? 'leticia' : 'heitor';
  const who = NAMES[from];

  const supabase = adminClient();

  const { data: title } = await supabase
    .from('titles')
    .select(
      'id, title, poster_path, backdrop_path, status, audience, added_by, created_at, current_season, current_episode',
    )
    .eq('id', titleId)
    .maybeSingle();
  if (!title) return json({ sent: 0, reason: 'título não existe' });

  let prefKey: string;
  let heading: string;
  let tag: string;

  switch (kind) {
    case 'progress': {
      // Só faz sentido avisar quando a pessoa assiste sozinha.
      if (title.status !== 'assistindo' || title.audience !== from) {
        return json({ sent: 0, reason: 'não está assistindo sozinho(a)' });
      }
      prefKey = 'episode_progress';
      heading = `${who} viu T${title.current_season ?? 1} · E${title.current_episode ?? 1} sem você`;
      tag = `progress-${title.id}`;
      break;
    }
    case 'comment': {
      const { data: row } = await supabase
        .from('episode_comments')
        .select('id')
        .eq('title_id', titleId)
        .eq('owner', from)
        .eq('season', season)
        .eq('episode', episode)
        .maybeSingle();
      if (!row) return json({ sent: 0, reason: 'comentário não existe' });
      prefKey = 'episode_comment';
      heading = `${who} comentou T${season} · E${episode}`;
      tag = `comment-${title.id}-${season}-${episode}`;
      break;
    }
    case 'series_comment': {
      const { data: row } = await supabase
        .from('ratings')
        .select('comment')
        .eq('title_id', titleId)
        .eq('owner', from)
        .maybeSingle();
      if (!row?.comment) return json({ sent: 0, reason: 'comentário não existe' });
      prefKey = 'series_comment';
      heading = `${who} comentou sobre`;
      tag = `series-comment-${title.id}`;
      break;
    }
    case 'title_added': {
      const recent = Date.now() - new Date(title.created_at).getTime() < RECENT_MS;
      if (title.added_by !== from || !recent) return json({ sent: 0, reason: 'adição não confere' });
      if (title.audience === 'juntos') {
        prefKey = 'title_added_both';
        heading = `${who} adicionou uma obra pra vocês`;
      } else if (title.audience === to) {
        prefKey = 'title_added_me';
        heading = `${who} adicionou uma obra pra você`;
      } else {
        prefKey = 'title_added_them';
        heading = `${who} adicionou uma obra pra si`;
      }
      tag = `added-${title.id}`;
      break;
    }
    case 'draw': {
      prefKey = 'draw';
      heading = `${who} sorteou o que vocês vão ver`;
      tag = `draw-${from}`;
      break;
    }
    case 'pick': {
      const { data: row } = await supabase
        .from('picks')
        .select('id')
        .eq('title_id', titleId)
        .eq('owner', from)
        .maybeSingle();
      if (!row) return json({ sent: 0, reason: 'escolha não existe' });
      prefKey = 'pick_added';
      heading = `${who} escolheu pra noite de cinema`;
      tag = `pick-${title.id}-${from}`;
      break;
    }
    default: {
      const { data: row } = await supabase
        .from('main_titles')
        .select('id')
        .eq('title_id', titleId)
        .eq('owner', from)
        .maybeSingle();
      if (!row) return json({ sent: 0, reason: 'série principal não confere' });
      prefKey = 'main_changed';
      heading = `${who} escolheu a série principal`;
      tag = `main-${from}`;
    }
  }

  if (!(await isEnabled(supabase, to, prefKey))) {
    return json({ sent: 0, reason: 'desativado por quem recebe' });
  }

  return json(await sendPush(supabase, to, {
    title: heading,
    body: title.title,
    icon: title.poster_path ? `${IMG}/w342${title.poster_path}` : undefined,
    image: title.backdrop_path ? `${IMG}/w780${title.backdrop_path}` : undefined,
    tag,
  }));
});
