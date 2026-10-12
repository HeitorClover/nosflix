import 'package:flutter/material.dart';
import '../models/audience.dart';
import '../models/episode_comment_model.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';

/// Conquista do casal: [current] de [target]; desbloqueada ao chegar no alvo.
class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final int current;
  final int target;

  const Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
  });

  bool get unlocked => current >= target;
  double get progress => (current / target).clamp(0.0, 1.0);
}

List<Achievement> computeAchievements(
  List<TitleModel> titles,
  List<RatingModel> ratings,
  List<EpisodeCommentModel> comments,
) {
  final together =
      titles.where((t) => t.status == WatchStatus.assistidoJuntos && t.audience == Audience.juntos).toList();
  final movies = together.where((t) => t.mediaType == 'movie').length;
  final series = together.where((t) => t.mediaType == 'tv').length;
  final longSeries = together.where((t) => t.mediaType == 'tv' && (t.currentSeason ?? 0) >= 5).length;
  final categories = {for (final t in together) t.category}.length;
  final recommendations = titles.where((t) => t.status == WatchStatus.recomendo).length;
  final soloWatching = titles.where((t) => t.status == WatchStatus.assistindo && t.audience.isSolo).length;
  final rated = ratings.where((r) => r.rating != null).length;
  final withComment = ratings.where((r) => (r.comment ?? '').trim().isNotEmpty).length;

  return [
    Achievement(
      title: 'Primeira sessão',
      description: 'Assistam o primeiro título juntos',
      icon: Icons.favorite_rounded,
      current: together.length,
      target: 1,
    ),
    Achievement(
      title: 'Cinéfilos',
      description: '10 filmes juntos',
      icon: Icons.movie_rounded,
      current: movies,
      target: 10,
    ),
    Achievement(
      title: 'Viciados em série',
      description: '5 séries terminadas juntos',
      icon: Icons.tv_rounded,
      current: series,
      target: 5,
    ),
    Achievement(
      title: 'Maratonistas',
      description: 'Terminem uma série de 5 temporadas ou mais',
      icon: Icons.local_fire_department_rounded,
      current: longSeries,
      target: 1,
    ),
    Achievement(
      title: 'Colecionadores',
      description: '25 títulos assistidos juntos',
      icon: Icons.emoji_events_rounded,
      current: together.length,
      target: 25,
    ),
    Achievement(
      title: 'Sem preconceito',
      description: 'Assistam juntos 4 categorias diferentes',
      icon: Icons.category_rounded,
      current: categories,
      target: 4,
    ),
    Achievement(
      title: 'Críticos de plantão',
      description: '20 avaliações com nota',
      icon: Icons.star_rounded,
      current: rated,
      target: 20,
    ),
    Achievement(
      title: 'Opinião forte',
      description: '15 comentários em títulos',
      icon: Icons.forum_rounded,
      current: withComment,
      target: 15,
    ),
    Achievement(
      title: 'Fofoqueiros',
      description: '25 comentários em episódios',
      icon: Icons.chat_bubble_rounded,
      current: comments.length,
      target: 25,
    ),
    Achievement(
      title: 'Cupidos',
      description: '5 indicações de um pro outro',
      icon: Icons.campaign_rounded,
      current: recommendations,
      target: 5,
    ),
    Achievement(
      title: 'Vida própria',
      description: 'Cada um com uma série só sua',
      icon: Icons.person_rounded,
      current: soloWatching,
      target: 2,
    ),
  ];
}
