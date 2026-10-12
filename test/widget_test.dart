import 'package:flutter_test/flutter_test.dart';
import 'package:nosflix/core/progress.dart';
import 'package:nosflix/core/stats.dart';
import 'package:nosflix/models/rating_model.dart';
import 'package:nosflix/models/title_model.dart';
import 'package:nosflix/models/tv_models.dart';
import 'package:nosflix/models/watch_status.dart';

const _seasons = [
  TvSeason(number: 1, episodeCount: 3, name: 'T1'),
  TvSeason(number: 2, episodeCount: 2, name: 'T2'),
];

TitleModel _title(String id, {WatchStatus status = WatchStatus.assistidoJuntos, List<String> genres = const []}) {
  return TitleModel(
    id: id,
    mediaType: 'tv',
    category: TitleCategory.serie,
    title: 'Título $id',
    genres: genres,
    status: status,
    addedBy: 'heitor',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

RatingModel _rating(String titleId, String owner, double? value, {DateTime? watchedAt}) {
  return RatingModel(
    id: '$titleId$owner',
    titleId: titleId,
    owner: owner,
    rating: value,
    watchedAt: watchedAt,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  group('nextEpisode', () {
    test('avança dentro da temporada', () {
      expect(nextEpisode(_seasons, 1, 1), const EpisodePos(1, 2));
    });

    test('passa para a próxima temporada no último episódio', () {
      expect(nextEpisode(_seasons, 1, 3), const EpisodePos(2, 1));
    });

    test('devolve null no último episódio da série', () {
      expect(nextEpisode(_seasons, 2, 2), isNull);
    });

    test('sem dados da TMDB só soma o episódio', () {
      expect(nextEpisode(const [], 4, 9), const EpisodePos(4, 10));
    });
  });

  group('isSpoilerHidden', () {
    bool hidden(WatchStatus status, int s, int e) => isSpoilerHidden(
          status: status,
          currentSeason: 1,
          currentEpisode: 3,
          season: s,
          episode: e,
        );

    test('episódios já vistos ficam visíveis', () {
      expect(hidden(WatchStatus.assistindo, 1, 3), isFalse);
      expect(hidden(WatchStatus.assistindo, 1, 1), isFalse);
    });

    test('episódios à frente do progresso ficam escondidos', () {
      expect(hidden(WatchStatus.assistindo, 1, 4), isTrue);
      expect(hidden(WatchStatus.assistindo, 2, 1), isTrue);
    });

    test('série terminada mostra tudo; recomendada/não vista esconde', () {
      expect(hidden(WatchStatus.assistidoJuntos, 9, 9), isFalse);
      expect(hidden(WatchStatus.recomendo, 1, 1), isTrue);
      expect(hidden(WatchStatus.queroVer, 1, 1), isTrue);
    });
  });

  group('computeStats', () {
    test('conta por status, média por pessoa e melhores notas', () {
      final titles = [
        _title('a', genres: ['Drama']),
        _title('b', status: WatchStatus.queroVer, genres: ['Drama']),
        _title('c', status: WatchStatus.assistindo, genres: ['Comédia', 'Drama']),
      ];
      final ratings = [
        _rating('a', 'heitor', 4, watchedAt: DateTime(2026, 3, 1)),
        _rating('a', 'leticia', 5, watchedAt: DateTime(2026, 3, 2)),
        _rating('c', 'heitor', 3),
        _rating('c', 'leticia', null),
      ];
      final stats = computeStats(titles, ratings);

      expect(stats.byStatus[WatchStatus.queroVer], 1);
      expect(stats.byStatus[WatchStatus.assistindo], 1);
      expect(stats.watchedByYear, {2026: 1});
      expect(stats.averageByOwner['heitor'], 3.5);
      expect(stats.averageByOwner['leticia'], 5);
      // "quero ver" não conta para gêneros favoritos.
      expect(stats.topGenres.first.key, 'Drama');
      expect(stats.topGenres.first.value, 2);
      expect(stats.topRated.first.title.id, 'a');
      expect(stats.topRated.first.average, 4.5);
    });
  });
}
