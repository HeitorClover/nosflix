import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/titles_repository.dart';
import '../core/news.dart';
import '../data/tmdb_service.dart';
import '../models/episode_comment_model.dart';
import '../models/pick_model.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';
import '../models/tv_models.dart';

final titlesRepositoryProvider = Provider<TitlesRepository>((ref) => TitlesRepository());

class TitlesNotifier extends AsyncNotifier<List<TitleModel>> {
  @override
  Future<List<TitleModel>> build() async {
    return ref.read(titlesRepositoryProvider).fetchAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(titlesRepositoryProvider).fetchAll());
  }

  Future<void> addTitle(Map<String, dynamic> json) async {
    final repo = ref.read(titlesRepositoryProvider);
    await repo.insert(json);
    await refresh();
  }

  Future<void> updateStatus(String titleId, String status, {String? recommendedBy}) async {
    final repo = ref.read(titlesRepositoryProvider);
    await repo.updateStatus(titleId: titleId, status: status, recommendedBy: recommendedBy);
    state = await AsyncValue.guard(() => repo.fetchAll());
  }

  Future<void> updateAudience(String titleId, String audience) async {
    final repo = ref.read(titlesRepositoryProvider);
    await repo.updateAudience(titleId: titleId, audience: audience);
    state = await AsyncValue.guard(() => repo.fetchAll());
  }

  Future<void> updateProgress(String titleId, {required int season, required int episode}) async {
    final repo = ref.read(titlesRepositoryProvider);
    await repo.updateProgress(titleId: titleId, season: season, episode: episode);
    state = await AsyncValue.guard(() => repo.fetchAll());
  }

  Future<void> deleteTitle(String titleId) async {
    final repo = ref.read(titlesRepositoryProvider);
    await repo.delete(titleId);
    await refresh();
  }
}

final titlesProvider = AsyncNotifierProvider<TitlesNotifier, List<TitleModel>>(TitlesNotifier.new);

final ratingsForTitleProvider = StreamProvider.family<List<RatingModel>, String>((ref, titleId) {
  return ref.read(titlesRepositoryProvider).watchRatingsForTitle(titleId);
});

final allRatingsProvider = StreamProvider<List<RatingModel>>((ref) {
  return ref.read(titlesRepositoryProvider).watchAllRatings();
});

final episodeCommentsProvider =
    StreamProvider.family<List<EpisodeCommentModel>, String>((ref, titleId) {
  return ref.read(titlesRepositoryProvider).watchEpisodeComments(titleId);
});

final tmdbServiceProvider = Provider<TmdbService>((ref) => TmdbService());

final tvDetailsProvider = FutureProvider.family<TvDetails, int>((ref, tmdbId) {
  return ref.read(tmdbServiceProvider).fetchTvDetails(tmdbId);
});

final tvSeasonsProvider = FutureProvider.family<List<TvSeason>, int>((ref, tmdbId) async {
  return (await ref.watch(tvDetailsProvider(tmdbId).future)).seasons;
});

final tvAirInfoProvider = FutureProvider.family<TvAirInfo, int>((ref, tmdbId) async {
  return (await ref.watch(tvDetailsProvider(tmdbId).future)).airInfo;
});

final trailerKeyProvider =
    FutureProvider.family<String?, ({int tmdbId, String mediaType})>((ref, key) {
  return ref.read(tmdbServiceProvider).fetchTrailerKey(key.tmdbId, key.mediaType);
});

final tvEpisodesProvider =
    FutureProvider.family<List<TvEpisode>, ({int tmdbId, int season})>((ref, key) {
  return ref.read(tmdbServiceProvider).fetchEpisodes(key.tmdbId, key.season);
});

final watchProvidersProvider =
    FutureProvider.family<WatchProviders, ({int tmdbId, String mediaType})>((ref, key) {
  return ref.read(tmdbServiceProvider).fetchWatchProviders(key.tmdbId, key.mediaType);
});

final picksProvider = StreamProvider<List<PickModel>>((ref) {
  return ref.read(titlesRepositoryProvider).watchPicks();
});

final allEpisodeCommentsProvider = StreamProvider<List<EpisodeCommentModel>>((ref) {
  return ref.read(titlesRepositoryProvider).watchAllEpisodeComments();
});

/// Novidades (episódio ou temporada nova) das séries que o casal acompanha.
final newsProvider = FutureProvider<List<NewsItem>>((ref) async {
  final titles = ref.watch(titlesProvider).valueOrNull ?? const <TitleModel>[];
  final candidates = titles
      .where((t) =>
          t.mediaType == 'tv' &&
          t.tmdbId != null &&
          (t.status == WatchStatus.assistindo || t.status == WatchStatus.assistidoJuntos))
      .take(20)
      .toList();
  final now = DateTime.now();
  final items = await Future.wait(candidates.map((t) async {
    try {
      final info = await ref.read(tvAirInfoProvider(t.tmdbId!).future);
      return newsFor(t, info, now);
    } catch (_) {
      return null;
    }
  }));
  return items.whereType<NewsItem>().toList()..sort((a, b) => a.date.compareTo(b.date));
});

/// Série principal de cada pessoa (o campo `owner` diz de quem é).
final mainTitlesProvider = StreamProvider<List<PickModel>>((ref) {
  return ref.read(titlesRepositoryProvider).watchMainTitles();
});
