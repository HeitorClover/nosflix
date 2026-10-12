// Utilidades compartilhadas pelas Edge Functions de push.
import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

export const NAMES: Record<string, string> = { heitor: 'Heitor', leticia: 'Leticia' };
export const IMG = 'https://image.tmdb.org/t/p';

/// Padrão de cada aviso quando a pessoa ainda não mexeu nele.
/// Precisa ficar igual a lib/core/notification_settings.dart.
export const DEFAULT_PREFS: Record<string, boolean> = {
  series_comment: true,
  episode_comment: true,
  episode_progress: true,
  title_added_both: true,
  title_added_them: false,
  title_added_me: false,
  recommend: true,
  draw: true,
  pick_added: false,
  main_changed: true,
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
}

/// Se [owner] quer receber o aviso [key] (preferência salva ou padrão).
export async function isEnabled(supabase: SupabaseClient, owner: string, key: string): Promise<boolean> {
  const { data } = await supabase
    .from('notification_prefs')
    .select('prefs')
    .eq('owner', owner)
    .maybeSingle();
  const value = (data?.prefs as Record<string, unknown> | undefined)?.[key];
  return typeof value === 'boolean' ? value : (DEFAULT_PREFS[key] ?? true);
}

/// Envia [payload] para todos os aparelhos inscritos de [to]. Devolve quantos receberam.
export async function sendPush(
  supabase: SupabaseClient,
  to: string,
  payload: Record<string, unknown>,
): Promise<{ sent: number; reason?: string }> {
  const { data: subs } = await supabase
    .from('push_subscriptions')
    .select('id, endpoint, p256dh, auth')
    .eq('owner', to);
  if (!subs || subs.length === 0) return { sent: 0, reason: 'sem inscrições' };

  webpush.setVapidDetails(
    Deno.env.get('VAPID_SUBJECT')!,
    Deno.env.get('VAPID_PUBLIC_KEY')!,
    Deno.env.get('VAPID_PRIVATE_KEY')!,
  );

  const body = JSON.stringify({ url: '/', ...payload });
  let sent = 0;
  await Promise.all(subs.map(async (s) => {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        body,
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
  return { sent };
}
