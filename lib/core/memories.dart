import '../models/rating_model.dart';
import '../models/title_model.dart';

/// Algo que o casal assistiu por volta desta data em anos anteriores.
class Memory {
  final TitleModel title;
  final DateTime watchedAt;
  final int yearsAgo;
  const Memory({required this.title, required this.watchedAt, required this.yearsAgo});
}

/// Títulos assistidos até [windowDays] dias antes ou depois de hoje, em anos passados.
List<Memory> memoriesNear(List<TitleModel> titles, List<RatingModel> ratings, DateTime now, {int windowDays = 3}) {
  final byId = {for (final t in titles) t.id: t};
  final best = <String, Memory>{};
  for (final r in ratings) {
    final d = r.watchedAt;
    final title = byId[r.titleId];
    if (d == null || title == null || d.year >= now.year) continue;
    // Compara a data no ano corrente (evita 29/02 quebrar em anos não bissextos).
    final sameDay = DateTime(now.year, d.month, d.day);
    if (sameDay.difference(DateTime(now.year, now.month, now.day)).inDays.abs() > windowDays) continue;
    best.putIfAbsent(r.titleId, () => Memory(title: title, watchedAt: d, yearsAgo: now.year - d.year));
  }
  return best.values.toList()..sort((a, b) => a.yearsAgo.compareTo(b.yearsAgo));
}

class YearReview {
  final int year;
  final int titleCount;
  final int? busiestMonth;
  final String? topGenre;
  final TitleModel? bestRated;
  final double? bestRating;
  final TitleModel? first;
  final TitleModel? last;

  const YearReview({
    required this.year,
    required this.titleCount,
    this.busiestMonth,
    this.topGenre,
    this.bestRated,
    this.bestRating,
    this.first,
    this.last,
  });
}

/// Anos em que há algum título com data de "quando assistiu", do mais novo ao mais antigo.
List<int> yearsWithWatches(List<RatingModel> ratings) {
  final years = {for (final r in ratings) if (r.watchedAt != null) r.watchedAt!.year};
  return years.toList()..sort((a, b) => b.compareTo(a));
}

YearReview yearInReview(List<TitleModel> titles, List<RatingModel> ratings, int year) {
  final byId = {for (final t in titles) t.id: t};
  final firstDate = <String, DateTime>{};
  final scores = <String, List<double>>{};
  for (final r in ratings) {
    final d = r.watchedAt;
    if (d == null || d.year != year || !byId.containsKey(r.titleId)) continue;
    final current = firstDate[r.titleId];
    if (current == null || d.isBefore(current)) firstDate[r.titleId] = d;
    if (r.rating != null) scores.putIfAbsent(r.titleId, () => []).add(r.rating!);
  }
  if (firstDate.isEmpty) return YearReview(year: year, titleCount: 0);

  final months = <int, int>{};
  final genres = <String, int>{};
  for (final e in firstDate.entries) {
    months[e.value.month] = (months[e.value.month] ?? 0) + 1;
    for (final g in byId[e.key]!.genres) {
      genres[g] = (genres[g] ?? 0) + 1;
    }
  }
  final busiest = months.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  final topGenre = genres.isEmpty ? null : genres.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  String? bestId;
  double bestScore = -1;
  for (final e in scores.entries) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    if (avg > bestScore) {
      bestScore = avg;
      bestId = e.key;
    }
  }

  final ordered = firstDate.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  return YearReview(
    year: year,
    titleCount: firstDate.length,
    busiestMonth: busiest,
    topGenre: topGenre,
    bestRated: bestId == null ? null : byId[bestId],
    bestRating: bestId == null ? null : bestScore,
    first: byId[ordered.first.key],
    last: byId[ordered.last.key],
  );
}
