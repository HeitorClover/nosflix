import 'package:flutter/material.dart';

enum WatchStatus { queroVer, assistindo, assistidoJuntos, recomendo }

extension WatchStatusX on WatchStatus {
  String get value => switch (this) {
        WatchStatus.queroVer => 'quero_ver',
        WatchStatus.assistindo => 'assistindo',
        WatchStatus.assistidoJuntos => 'assistido_juntos',
        WatchStatus.recomendo => 'recomendo',
      };

  String get label => switch (this) {
        WatchStatus.queroVer => 'Temos que ver juntos',
        WatchStatus.assistindo => 'Assistindo',
        WatchStatus.assistidoJuntos => 'Já vimos juntos',
        WatchStatus.recomendo => 'Recomendo',
      };

  IconData get icon => switch (this) {
        WatchStatus.queroVer => Icons.bookmark_add_outlined,
        WatchStatus.assistindo => Icons.play_circle_outline,
        WatchStatus.assistidoJuntos => Icons.favorite,
        WatchStatus.recomendo => Icons.campaign_outlined,
      };

  static WatchStatus fromValue(String value) => WatchStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => WatchStatus.queroVer,
      );
}

enum TitleCategory { filme, serie, desenho, anime, documentario, outro }

extension TitleCategoryX on TitleCategory {
  String get value => switch (this) {
        TitleCategory.filme => 'filme',
        TitleCategory.serie => 'serie',
        TitleCategory.desenho => 'desenho',
        TitleCategory.anime => 'anime',
        TitleCategory.documentario => 'documentario',
        TitleCategory.outro => 'outro',
      };

  String get label => switch (this) {
        TitleCategory.filme => 'Filme',
        TitleCategory.serie => 'Série',
        TitleCategory.desenho => 'Desenho',
        TitleCategory.anime => 'Anime',
        TitleCategory.documentario => 'Documentário',
        TitleCategory.outro => 'Outro',
      };

  IconData get icon => switch (this) {
        TitleCategory.filme => Icons.movie_outlined,
        TitleCategory.serie => Icons.tv_outlined,
        TitleCategory.desenho => Icons.brush_outlined,
        TitleCategory.anime => Icons.auto_awesome_outlined,
        TitleCategory.documentario => Icons.travel_explore_outlined,
        TitleCategory.outro => Icons.category_outlined,
      };

  static TitleCategory fromValue(String value) => TitleCategory.values.firstWhere(
        (c) => c.value == value,
        orElse: () => TitleCategory.outro,
      );
}
