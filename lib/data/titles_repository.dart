import '../models/rating_model.dart';
import '../models/title_model.dart';
import 'supabase_client.dart';

class TitlesRepository {
  Future<List<TitleModel>> fetchAll() async {
    final rows = await supabase.from('titles').select().order('updated_at', ascending: false);
    return (rows as List).map((r) => TitleModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<TitleModel> insert(Map<String, dynamic> json) async {
    final row = await supabase.from('titles').insert(json).select().single();
    return TitleModel.fromJson(row);
  }

  Future<void> updateStatus({
    required String titleId,
    required String status,
    String? recommendedBy,
  }) async {
    await supabase.from('titles').update({
      'status': status,
      'recommended_by': recommendedBy,
    }).eq('id', titleId);
  }

  Future<void> delete(String titleId) async {
    await supabase.from('titles').delete().eq('id', titleId);
  }

  Future<List<RatingModel>> fetchRatingsForTitle(String titleId) async {
    final rows = await supabase.from('ratings').select().eq('title_id', titleId);
    return (rows as List).map((r) => RatingModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> upsertRating(RatingModel rating) async {
    await supabase.from('ratings').upsert(
          rating.toUpsertJson(rating.titleId),
          onConflict: 'title_id,owner',
        );
  }

  Future<bool> existsByTmdbId(int tmdbId, String mediaType) async {
    final rows = await supabase
        .from('titles')
        .select('id')
        .eq('tmdb_id', tmdbId)
        .eq('media_type', mediaType)
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}
