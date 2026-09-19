import 'dart:convert';
import '../../data/supabase_client.dart';
import '../theme/app_theme.dart';
import 'push_platform_stub.dart' if (dart.library.js_interop) 'push_platform_web.dart' as platform;

/// Chave pública VAPID (a privada fica só nos secrets da Edge Function).
const _vapidPublicKey =
    'BJXimZw8lll8gEl5i_Ot3Av_g5bX0KisViwPRHgCvuEnq1XC2gGlV3XeUOmsnk5LHMZpaG9d_r4erlIjCcBKd_k';

/// [needsInstall]: iPhone no Safari comum; precisa instalar na Tela de Início.
enum PushStatus { unsupported, needsInstall, blocked, off, on }

class PushService {
  /// Estado atual das notificações neste aparelho.
  static PushStatus status() {
    if (!platform.pushSupported()) {
      return platform.pushNeedsInstall() ? PushStatus.needsInstall : PushStatus.unsupported;
    }
    return switch (platform.pushPermission()) {
      'granted' => PushStatus.on,
      'denied' => PushStatus.blocked,
      _ => PushStatus.off,
    };
  }

  /// Pede permissão (deve ser chamado direto de um toque) e registra este
  /// aparelho para o perfil. Devolve o estado resultante.
  static Future<PushStatus> enable(Profile profile) async {
    await _register(profile, prompt: true);
    return status();
  }

  /// Se já há permissão, garante que este aparelho está registrado para o
  /// perfil atual (útil ao trocar de perfil no mesmo aparelho).
  static Future<void> syncIfGranted(Profile profile) async {
    if (status() != PushStatus.on) return;
    try {
      await _register(profile, prompt: false);
    } catch (_) {
      // Sincronização silenciosa: falha aqui não deve atrapalhar o app.
    }
  }

  static Future<void> _register(Profile profile, {required bool prompt}) async {
    final raw = await platform.pushSubscribe(_vapidPublicKey, prompt: prompt);
    if (raw == null) return;
    final sub = jsonDecode(raw) as Map<String, dynamic>;
    final keys = sub['keys'] as Map<String, dynamic>;
    await supabase.from('push_subscriptions').upsert({
      'owner': profile.name,
      'endpoint': sub['endpoint'],
      'p256dh': keys['p256dh'],
      'auth': keys['auth'],
    }, onConflict: 'endpoint');
  }

  /// Pede para a Edge Function avisar a outra pessoa sobre a recomendação.
  static Future<void> notifyRecommendation({required String titleId, required Profile from}) async {
    try {
      await supabase.functions.invoke(
        'notify-recommendation',
        body: {'titleId': titleId, 'from': from.name},
      );
    } catch (_) {
      // A recomendação já foi salva; se o aviso falhar, não desfazemos nada.
    }
  }
}
