import 'dart:math';
import '../models/audience.dart';
import '../models/pick_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';

const maxPicksPerPerson = 3;

/// Títulos que entram no sorteio/votação: "quero ver" dos dois juntos.
/// Filtros opcionais por categoria e por tipo (filme/série).
List<TitleModel> movieNightPool(
  List<TitleModel> titles, {
  TitleCategory? category,
  String? mediaType,
}) {
  return titles
      .where((t) =>
          t.status == WatchStatus.queroVer &&
          t.audience == Audience.juntos &&
          (category == null || t.category == category) &&
          (mediaType == null || t.mediaType == mediaType))
      .toList();
}

/// Títulos que os dois escolheram.
Set<String> matchingPicks(List<PickModel> picks) {
  final heitor = {for (final p in picks) if (p.owner == 'heitor') p.titleId};
  final leticia = {for (final p in picks) if (p.owner == 'leticia') p.titleId};
  return heitor.intersection(leticia);
}

/// Sorteia um título; devolve `null` se a lista estiver vazia.
TitleModel? drawOne(List<TitleModel> candidates, [Random? random]) {
  if (candidates.isEmpty) return null;
  return candidates[(random ?? Random()).nextInt(candidates.length)];
}
