// Plataformas sem Web Push (builds nativos, ex.: Windows): nada a fazer.
bool pushSupported() => false;

bool pushNeedsInstall() => false;

String pushPermission() => 'denied';

Future<String?> pushSubscribe(String vapidKey, {required bool prompt}) async => null;
