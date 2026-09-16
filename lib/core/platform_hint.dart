import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'theme/app_theme.dart';

/// Sugere qual perfil é mais provável neste dispositivo, com base na
/// plataforma: Heitor usa o APK Android, Leticia usa a web/PWA (ou iOS).
/// É só uma sugestão pré-selecionada na tela de login — o usuário sempre
/// pode escolher o outro perfil manualmente.
Profile suggestedProfile() {
  if (kIsWeb) return Profile.leticia;
  if (defaultTargetPlatform == TargetPlatform.android) return Profile.heitor;
  return Profile.leticia;
}
