import 'dart:js_interop';

@JS('nosflixPush')
external _NosflixPush? get _push;

extension type _NosflixPush._(JSObject _) implements JSObject {
  external bool supported();
  external bool needsInstall();
  external String permission();
  external JSPromise<JSString?> subscribe(String vapidKey, bool prompt);
}

bool pushSupported() => _push?.supported() ?? false;

bool pushNeedsInstall() => _push?.needsInstall() ?? false;

String pushPermission() => _push?.permission() ?? 'denied';

/// JSON da inscrição push, ou null se não há permissão / não é suportado.
Future<String?> pushSubscribe(String vapidKey, {required bool prompt}) async {
  final push = _push;
  if (push == null) return null;
  final result = await push.subscribe(vapidKey, prompt).toDart;
  return result?.toDart;
}
