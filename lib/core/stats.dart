import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';

class TitleScore {
  final TitleModel title;
  final double average;
  const TitleScore(this.title, this.average);
}

class NosflixStats {
  final Map<WatchStatus, int> byStatus;
  final Map<int, int> watchedByYear;
  final Map<String, double> averageByOwner;
  final List<MapEntry<String, int>> topGenres;
  final List<TitleScore> topRated;

  const NosflixStats({
    required this.byStatus,
    required this.watchedByYear,
    required this.averageByOwner,
    required this.topGenres,
    required this.topRated,
  });
}

NosflixStats computeStats(List<TitleModel> titles, List<RatingModel> ratings) {
  final byStatus = {for (final s in WatchStatus.values) s: 0};
  for (final t in titles) {
    byStatus[t.status] = byStatus[t.status]! + 1;
  }

  // Títulos distintos por ano em que alguém marcou que assistiu.
  final yearTitles = <int, Set<String>>{};
  for (final r in ratings) {
    final d = r.watchedAt;
    if (d != null) yearTitles.putIfAbsent(d.year, () => {}).add(r.titleId);
  }
  final watchedByYear = {for (final e in yearTitles.entries) e.key: e.value.length};

  final sums = <String, List<double>>{};
  final perTitle = <String, List<double>>{};
  for (final r in ratings) {
    final v = r.rating;
    if (v == null) continue;
    sums.putIfAbsent(r.owner, () => []).add(v);
    perTitle.putIfAbsent(r.titleId, () => []).add(v);
  }
  double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
  final averageByOwner = {for (final e in sums.entries) e.key: avg(e.value)};

  final genreCount = <String, int>{};
  for (final t in titles) {
    if (t.status == WatchStatus.queroVer) continue;
    for (final g in t.genres) {
      genreCount[g] = (genreCount[g] ?? 0) + 1;
    }
  }
  final topGenres = genreCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  final byId = {for (final t in titles) t.id: t};
  final topRated = [
    for (final e in perTitle.entries)
      if (byId[e.key] != null) TitleScore(byId[e.key]!, avg(e.value)),
  ]..sort((a, b) => b.average.compareTo(a.average));

  return NosflixStats(
    byStatus: byStatus,
    watchedByYear: watchedByYear,
    averageByOwner: averageByOwner,
    topGenres: topGenres.take(5).toList(),
    topRated: topRated.take(5).toList(),
  );
}
