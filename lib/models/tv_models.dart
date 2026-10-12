/// Temporada de uma série, vinda da TMDB.
class TvSeason {
  final int number;
  final int episodeCount;
  final String name;
  const TvSeason({required this.number, required this.episodeCount, required this.name});
}

class TvEpisode {
  final int number;
  final String name;
  const TvEpisode({required this.number, required this.name});
}

class WatchProvider {
  final String name;
  final String? logoPath;
  const WatchProvider({required this.name, this.logoPath});

  String? get logoUrl => logoPath == null ? null : 'https://image.tmdb.org/t/p/w92$logoPath';
}

/// Onde o título está disponível no Brasil (dados JustWatch via TMDB).
class WatchProviders {
  final List<WatchProvider> stream;
  final List<WatchProvider> rent;
  final List<WatchProvider> buy;
  const WatchProviders({this.stream = const [], this.rent = const [], this.buy = const []});

  bool get isEmpty => stream.isEmpty && rent.isEmpty && buy.isEmpty;
}

/// Situação de exibição de uma série: próximo episódio e última temporada no ar.
class TvAirInfo {
  final bool ended;
  final DateTime? nextAirDate;
  final int? nextSeason;
  final int? nextEpisode;
  final DateTime? lastAirDate;
  final int lastSeason;

  const TvAirInfo({
    this.ended = false,
    this.nextAirDate,
    this.nextSeason,
    this.nextEpisode,
    this.lastAirDate,
    this.lastSeason = 0,
  });
}

class TvDetails {
  final List<TvSeason> seasons;
  final TvAirInfo airInfo;
  const TvDetails({this.seasons = const [], this.airInfo = const TvAirInfo()});
}
