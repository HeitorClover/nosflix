import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/titles_repository.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';

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
    await refresh();
  }

  Future<void> deleteTitle(String titleId) async {
    final repo = ref.read(titlesRepositoryProvider);
    await repo.delete(titleId);
    await refresh();
  }
}

final titlesProvider = AsyncNotifierProvider<TitlesNotifier, List<TitleModel>>(TitlesNotifier.new);

final ratingsForTitleProvider =
    FutureProvider.family<List<RatingModel>, String>((ref, titleId) async {
  return ref.read(titlesRepositoryProvider).fetchRatingsForTitle(titleId);
});
