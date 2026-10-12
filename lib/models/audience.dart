import '../core/theme/app_theme.dart';

/// Para quem é o título: os dois juntos ou só um deles. Vale para a lista de
/// desejos ("quero ver") e para quem está assistindo.
enum Audience { juntos, heitor, leticia }

extension AudienceX on Audience {
  String get value => name;

  static Audience fromValue(String? value) =>
      Audience.values.firstWhere((a) => a.name == value, orElse: () => Audience.juntos);

  static Audience solo(Profile p) => p == Profile.heitor ? Audience.heitor : Audience.leticia;

  bool get isSolo => this != Audience.juntos;

  Profile? get profile => switch (this) {
        Audience.juntos => null,
        Audience.heitor => Profile.heitor,
        Audience.leticia => Profile.leticia,
      };

  /// Rótulo do ponto de vista de [me] ("Só eu", "Só a Leticia").
  String labelFor(Profile me) {
    final p = profile;
    if (p == null) return 'Nós dois';
    return p == me ? 'Só eu' : 'Só ${p.displayName}';
  }
}
