import '../models/tv_models.dart';
import '../models/watch_status.dart';

class EpisodePos {
  final int season;
  final int episode;
  const EpisodePos(this.season, this.episode);

  bool isAfter(EpisodePos other) =>
      season > other.season || (season == other.season && episode > other.episode);

  @override
  bool operator ==(Object other) =>
      other is EpisodePos && other.season == season && other.episode == episode;

  @override
  int get hashCode => Object.hash(season, episode);
}

/// Próximo episódio depois de [season]/[episode]. Passa para a temporada
/// seguinte quando a atual acaba e devolve `null` se era o último da série.
/// Sem dados da TMDB ([seasons] vazio), só avança o episódio.
EpisodePos? nextEpisode(List<TvSeason> seasons, int season, int episode) {
  if (seasons.isEmpty) return EpisodePos(season, episode + 1);
  final ordered = [...seasons]..sort((a, b) => a.number.compareTo(b.number));
  final current = ordered.where((s) => s.number == season).firstOrNull;
  if (current != null && episode < current.episodeCount) return EpisodePos(season, episode + 1);
  final next = ordered.where((s) => s.number > season && s.episodeCount > 0).firstOrNull;
  return next == null ? null : EpisodePos(next.number, 1);
}

/// Número máximo de episódios da temporada, ou `null` se não se sabe.
int? episodeCountOf(List<TvSeason> seasons, int season) =>
    seasons.where((s) => s.number == season).firstOrNull?.episodeCount;

/// Comentário do parceiro no episódio [season]/[episode] fica escondido
/// (anti-spoiler) enquanto o casal ainda não chegou lá.
bool isSpoilerHidden({
  required WatchStatus status,
  required int? currentSeason,
  required int? currentEpisode,
  required int season,
  required int episode,
  bool viewerInAudience = true,
}) {
  // Série vista/assistida só pelo outro: tudo o que o outro comentou é spoiler.
  if (!viewerInAudience && (status == WatchStatus.assistindo || status == WatchStatus.assistidoJuntos)) {
    return true;
  }
  switch (status) {
    case WatchStatus.assistidoJuntos:
      return false;
    case WatchStatus.assistindo:
      final current = EpisodePos(currentSeason ?? 1, currentEpisode ?? 1);
      return EpisodePos(season, episode).isAfter(current);
    case WatchStatus.queroVer:
    case WatchStatus.recomendo:
      return true;
  }
}
