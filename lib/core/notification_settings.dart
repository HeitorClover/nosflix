import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

/// Um aviso que a pessoa pode ligar ou desligar.
class NotificationSetting {
  final String key;
  final String title;
  final String? subtitle;
  final bool defaultValue;

  const NotificationSetting({
    required this.key,
    required this.title,
    this.subtitle,
    required this.defaultValue,
  });
}

class NotificationGroup {
  final String title;
  final IconData icon;
  final List<NotificationSetting> settings;
  const NotificationGroup({required this.title, required this.icon, required this.settings});
}

/// Chaves dos avisos (iguais às de supabase/functions/_shared/push.ts).
class NotifKey {
  static const seriesComment = 'series_comment';
  static const episodeComment = 'episode_comment';
  static const episodeProgress = 'episode_progress';
  static const titleAddedBoth = 'title_added_both';
  static const titleAddedThem = 'title_added_them';
  static const titleAddedMe = 'title_added_me';
  static const recommend = 'recommend';
  static const draw = 'draw';
  static const pickAdded = 'pick_added';
  static const mainChanged = 'main_changed';
}

/// Todos os avisos, agrupados, do ponto de vista de [me] (os textos citam o outro).
List<NotificationGroup> notificationGroups(Profile me) {
  final other = me == Profile.heitor ? Profile.leticia : Profile.heitor;
  final name = other.displayName;
  return [
    NotificationGroup(
      title: 'Obras e episódios',
      icon: Icons.tv_rounded,
      settings: [
        NotificationSetting(
          key: NotifKey.seriesComment,
          title: '$name comentou uma obra',
          subtitle: 'Comentário em um filme, série, desenho ou anime',
          defaultValue: true,
        ),
        NotificationSetting(
          key: NotifKey.episodeComment,
          title: '$name comentou um episódio',
          subtitle: 'Sem mostrar o texto, para não dar spoiler',
          defaultValue: true,
        ),
        NotificationSetting(
          key: NotifKey.episodeProgress,
          title: '$name avançou um episódio',
          subtitle: 'Só quando $name assiste a série sozinho(a)',
          defaultValue: true,
        ),
      ],
    ),
    NotificationGroup(
      title: '$name adicionou uma obra',
      icon: Icons.add_circle_outline_rounded,
      settings: [
        const NotificationSetting(
          key: NotifKey.titleAddedBoth,
          title: 'Para nós dois',
          defaultValue: true,
        ),
        NotificationSetting(
          key: NotifKey.titleAddedThem,
          title: 'Só para $name',
          defaultValue: false,
        ),
        const NotificationSetting(
          key: NotifKey.titleAddedMe,
          title: 'Só para mim',
          defaultValue: false,
        ),
      ],
    ),
    NotificationGroup(
      title: 'Indicações e destaque',
      icon: Icons.campaign_outlined,
      settings: [
        NotificationSetting(
          key: NotifKey.recommend,
          title: '$name recomendou algo',
          defaultValue: true,
        ),
        NotificationSetting(
          key: NotifKey.mainChanged,
          title: '$name escolheu ou trocou a série principal',
          defaultValue: true,
        ),
      ],
    ),
    NotificationGroup(
      title: 'Noite de cinema',
      icon: Icons.theaters_rounded,
      settings: [
        NotificationSetting(
          key: NotifKey.draw,
          title: '$name sorteou o que vamos ver',
          defaultValue: true,
        ),
        NotificationSetting(
          key: NotifKey.pickAdded,
          title: '$name escolheu algo para sortear',
          subtitle: 'Quando $name marca um título na votação',
          defaultValue: false,
        ),
      ],
    ),
  ];
}

/// Valor do aviso [key] dado o que foi salvo em [saved] (usa o padrão se não houver).
bool prefEnabled(Map<String, dynamic> saved, String key) {
  final value = saved[key];
  if (value is bool) return value;
  return _defaults[key] ?? true;
}

final Map<String, bool> _defaults = {
  for (final g in notificationGroups(Profile.heitor))
    for (final s in g.settings) s.key: s.defaultValue,
};
