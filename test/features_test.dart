import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosflix/core/achievements.dart';
import 'package:nosflix/core/memories.dart';
import 'package:nosflix/core/movie_night.dart';
import 'package:nosflix/core/news.dart';
import 'package:nosflix/core/notification_settings.dart';
import 'package:nosflix/core/progress.dart';
import 'package:nosflix/core/theme/app_theme.dart';
import 'package:nosflix/models/audience.dart';
import 'package:nosflix/models/pick_model.dart';
import 'package:nosflix/models/rating_model.dart';
import 'package:nosflix/models/title_model.dart';
import 'package:nosflix/models/tv_models.dart';
import 'package:nosflix/models/watch_status.dart';

TitleModel _title(
  String id, {
  WatchStatus status = WatchStatus.queroVer,
  Audience audience = Audience.juntos,
  String mediaType = 'movie',
  int? season,
  List<String> genres = const [],
}) {
  return TitleModel(
    id: id,
    mediaType: mediaType,
    category: mediaType == 'tv' ? TitleCategory.serie : TitleCategory.filme,
    title: 'T$id',
    genres: genres,
    status: status,
    audience: audience,
    currentSeason: season,
    addedBy: 'heitor',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

RatingModel _rating(String titleId, String owner, {double? value, DateTime? watchedAt, String? comment}) {
  return RatingModel(
    id: '$titleId$owner',
    titleId: titleId,
    owner: owner,
    rating: value,
    comment: comment,
    watchedAt: watchedAt,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  group('avisos', () {
    test('padrões: ligado onde pedido, desligado nos demais', () {
      for (final key in [
        NotifKey.seriesComment,
        NotifKey.episodeComment,
        NotifKey.episodeProgress,
        NotifKey.titleAddedBoth,
        NotifKey.recommend,
        NotifKey.draw,
        NotifKey.mainChanged,
      ]) {
        expect(prefEnabled(const {}, key), isTrue, reason: key);
      }
      for (final key in [NotifKey.titleAddedThem, NotifKey.titleAddedMe, NotifKey.pickAdded]) {
        expect(prefEnabled(const {}, key), isFalse, reason: key);
      }
    });

    test('o que a pessoa salvou vale mais que o padrão', () {
      expect(prefEnabled({NotifKey.draw: false}, NotifKey.draw), isFalse);
      expect(prefEnabled({NotifKey.pickAdded: true}, NotifKey.pickAdded), isTrue);
    });

    test('padrões do app são os mesmos da Edge Function', () {
      final ts = File('supabase/functions/_shared/push.ts').readAsStringSync();
      final block = RegExp(r'DEFAULT_PREFS[^{]*\{([^}]*)\}').firstMatch(ts)!.group(1)!;
      final fromTs = {
        for (final m in RegExp(r'(\w+):\s*(true|false)').allMatches(block)) m.group(1)!: m.group(2) == 'true',
      };
      final fromApp = {
        for (final g in notificationGroups(Profile.heitor))
          for (final setting in g.settings) setting.key: setting.defaultValue,
      };
      expect(fromTs, fromApp);
    });
  });

  spoilerSoloTests();
  group('Audience', () {
    test('rótulos do ponto de vista de cada perfil', () {
      expect(Audience.juntos.labelFor(Profile.heitor), 'Nós dois');
      expect(Audience.heitor.labelFor(Profile.heitor), 'Só eu');
      expect(Audience.leticia.labelFor(Profile.heitor), 'Só Leticia');
    });

    test('valor desconhecido cai em "juntos"', () {
      expect(AudienceX.fromValue(null), Audience.juntos);
      expect(AudienceX.fromValue('xyz'), Audience.juntos);
      expect(AudienceX.solo(Profile.leticia), Audience.leticia);
    });
  });

  group('movie night', () {
    final titles = [
      _title('a'),
      _title('b', mediaType: 'tv'),
      _title('c', audience: Audience.heitor),
      _title('d', status: WatchStatus.assistindo),
    ];

    test('o sorteio só considera "ver juntos"', () {
      expect(movieNightPool(titles).map((t) => t.id), ['a', 'b']);
      expect(movieNightPool(titles, mediaType: 'tv').map((t) => t.id), ['b']);
    });

    test('acha os títulos que os dois escolheram', () {
      final picks = [
        const PickModel(id: '1', owner: 'heitor', titleId: 'a'),
        const PickModel(id: '2', owner: 'heitor', titleId: 'b'),
        const PickModel(id: '3', owner: 'leticia', titleId: 'b'),
      ];
      expect(matchingPicks(picks), {'b'});
    });

    test('drawOne devolve null sem candidatos e um item com candidatos', () {
      expect(drawOne(const []), isNull);
      expect(drawOne([titles.first], Random(1)), titles.first);
    });
  });

  group('newsFor', () {
    final now = DateTime(2026, 10, 1);
    final show = _title('s', status: WatchStatus.assistindo, mediaType: 'tv', season: 1);

    test('avisa de episódio que sai em breve', () {
      final item = newsFor(
        show,
        TvAirInfo(nextAirDate: DateTime(2026, 10, 2), nextSeason: 1, nextEpisode: 5, lastSeason: 1),
        now,
      );
      expect(item?.text, 'T1 · E5 amanhã');
      expect(item?.upcoming, isTrue);
    });

    test('estreia de temporada nova é destacada', () {
      final item = newsFor(
        show,
        TvAirInfo(nextAirDate: DateTime(2026, 10, 1), nextSeason: 2, nextEpisode: 1, lastSeason: 1),
        now,
      );
      expect(item?.text, 'Temporada 2 estreia hoje');
    });

    test('temporada lançada há pouco e ainda não vista', () {
      final item = newsFor(show, TvAirInfo(lastAirDate: DateTime(2026, 9, 20), lastSeason: 2), now);
      expect(item?.text, 'Temporada 2 no ar');
    });

    test('ignora o que está longe, já visto ou não é série acompanhada', () {
      expect(newsFor(show, TvAirInfo(nextAirDate: DateTime(2027, 3, 1), lastSeason: 1), now), isNull);
      expect(newsFor(show, TvAirInfo(lastAirDate: DateTime(2026, 9, 20), lastSeason: 1), now), isNull);
      expect(newsFor(_title('m'), const TvAirInfo(), now), isNull);
      expect(
        newsFor(_title('w', mediaType: 'tv'), TvAirInfo(nextAirDate: DateTime(2026, 10, 2)), now),
        isNull,
      );
    });
  });

  group('memórias e retrospectiva', () {
    final titles = [
      _title('a', status: WatchStatus.assistidoJuntos, genres: ['Drama']),
      _title('b', status: WatchStatus.assistidoJuntos, genres: ['Drama', 'Comédia']),
    ];
    final ratings = [
      _rating('a', 'heitor', value: 4, watchedAt: DateTime(2025, 10, 2)),
      _rating('a', 'leticia', value: 5, watchedAt: DateTime(2025, 10, 2)),
      _rating('b', 'heitor', value: 3, watchedAt: DateTime(2025, 3, 20)),
    ];

    test('lembra do que foi assistido perto desta data em anos anteriores', () {
      final memories = memoriesNear(titles, ratings, DateTime(2026, 10, 1));
      expect(memories.map((m) => m.title.id), ['a']);
      expect(memories.single.yearsAgo, 1);
    });

    test('não lembra de assistidos neste ano', () {
      expect(memoriesNear(titles, ratings, DateTime(2025, 10, 3)), isEmpty);
    });

    test('resume o ano', () {
      final review = yearInReview(titles, ratings, 2025);
      expect(review.titleCount, 2);
      expect(review.topGenre, 'Drama');
      expect(review.bestRated?.id, 'a');
      expect(review.bestRating, 4.5);
      expect(review.first?.id, 'b');
      expect(review.last?.id, 'a');
      expect(yearsWithWatches(ratings), [2025]);
      expect(yearInReview(titles, ratings, 2020).titleCount, 0);
    });
  });

  group('conquistas', () {
    test('desbloqueiam ao atingir a meta', () {
      final titles = [
        _title('a', status: WatchStatus.assistidoJuntos),
        _title('b', status: WatchStatus.assistidoJuntos, mediaType: 'tv', season: 5),
        _title('c', status: WatchStatus.assistindo, audience: Audience.heitor),
        _title('d', status: WatchStatus.assistindo, audience: Audience.leticia),
      ];
      final result = computeAchievements(titles, const [], const []);
      Achievement byTitle(String name) => result.firstWhere((a) => a.title == name);

      expect(byTitle('Primeira sessão').unlocked, isTrue);
      expect(byTitle('Maratonistas').unlocked, isTrue);
      expect(byTitle('Vida própria').unlocked, isTrue);
      expect(byTitle('Cinéfilos').unlocked, isFalse);
      expect(byTitle('Cinéfilos').current, 1);
      expect(byTitle('Cinéfilos').progress, closeTo(0.1, 1e-9));
    });
  });
}

void spoilerSoloTests() {
  group('anti-spoiler em título só de um', () {
    bool hidden({required bool inAudience, WatchStatus status = WatchStatus.assistidoJuntos}) => isSpoilerHidden(
          status: status,
          currentSeason: 1,
          currentEpisode: 1,
          season: 1,
          episode: 1,
          viewerInAudience: inAudience,
        );

    test('quem não assistiu não vê os comentários do outro', () {
      expect(hidden(inAudience: false), isTrue);
      expect(hidden(inAudience: false, status: WatchStatus.assistindo), isTrue);
    });

    test('quem assistiu vê normalmente', () {
      expect(hidden(inAudience: true), isFalse);
    });
  });
}
