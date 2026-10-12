import '../models/episode_comment_model.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pick_model.dart';
import 'supabase_client.dart';

class TitlesRepository {
  static const _cacheKey = 'nosflix_titles_cache';

  /// `true` quando o último `fetchAll` caiu no cache por falta de conexão.
  static bool lastFetchWasOffline = false;

  /// Busca o catálogo; sem conexão, devolve a última cópia salva no aparelho.
  Future<List<TitleModel>> fetchAll() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = await supabase.from('titles').select().order('updated_at', ascending: false);
      lastFetchWasOffline = false;
      await prefs.setString(_cacheKey, jsonEncode(rows));
      return (rows as List).map((r) => TitleModel.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      final cached = prefs.getString(_cacheKey);
      if (cached == null) rethrow;
      lastFetchWasOffline = true;
      return (jsonDecode(cached) as List).map((r) => TitleModel.fromJson(r as Map<String, dynamic>)).toList();
    }
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

  Future<void> updateProgress({
    required String titleId,
    required int season,
    required int episode,
  }) async {
    await supabase.from('titles').update({
      'current_season': season,
      'current_episode': episode,
    }).eq('id', titleId);
  }

  Future<void> updateAudience({required String titleId, required String audience}) async {
    await supabase.from('titles').update({'audience': audience}).eq('id', titleId);
  }

  Stream<List<PickModel>> watchPicks() {
    return supabase
        .from('picks')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(PickModel.fromJson).toList());
  }

  /// Série principal de cada pessoa (no máximo uma por pessoa).
  Stream<List<PickModel>> watchMainTitles() {
    return supabase
        .from('main_titles')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(PickModel.fromJson).toList());
  }

  Future<void> setMainTitle({required String owner, required String titleId}) async {
    await supabase.from('main_titles').upsert({'owner': owner, 'title_id': titleId}, onConflict: 'owner');
  }

  Future<void> clearMainTitle(String owner) async {
    await supabase.from('main_titles').delete().eq('owner', owner);
  }

  /// Preferências de notificação de [owner], ao vivo (só o que foi mudado).
  Stream<Map<String, dynamic>> watchNotificationPrefs(String owner) {
    return supabase
        .from('notification_prefs')
        .stream(primaryKey: ['owner'])
        .eq('owner', owner)
        .map((rows) => rows.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(rows.first['prefs'] as Map));
  }

  Future<void> saveNotificationPrefs(String owner, Map<String, dynamic> prefs) async {
    await supabase.from('notification_prefs').upsert({'owner': owner, 'prefs': prefs}, onConflict: 'owner');
  }

  Future<void> addPick({required String owner, required String titleId}) async {
    await supabase.from('picks').upsert({'owner': owner, 'title_id': titleId}, onConflict: 'owner,title_id');
  }

  Future<void> removePick({required String owner, required String titleId}) async {
    await supabase.from('picks').delete().eq('owner', owner).eq('title_id', titleId);
  }

  Future<void> clearPicks() async {
    // O filtro é obrigatório no delete; created_at nunca é nulo.
    await supabase.from('picks').delete().not('created_at', 'is', null);
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

  /// Avaliações de um título, ao vivo (o parceiro vê a nota/comentário na hora).
  Stream<List<RatingModel>> watchRatingsForTitle(String titleId) {
    return supabase
        .from('ratings')
        .stream(primaryKey: ['id'])
        .eq('title_id', titleId)
        .map((rows) => rows.map(RatingModel.fromJson).toList());
  }

  Stream<List<RatingModel>> watchAllRatings() {
    return supabase
        .from('ratings')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(RatingModel.fromJson).toList());
  }

  Stream<List<EpisodeCommentModel>> watchEpisodeComments(String titleId) {
    return supabase
        .from('episode_comments')
        .stream(primaryKey: ['id'])
        .eq('title_id', titleId)
        .map((rows) => rows.map(EpisodeCommentModel.fromJson).toList());
  }

  Stream<List<EpisodeCommentModel>> watchAllEpisodeComments() {
    return supabase
        .from('episode_comments')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(EpisodeCommentModel.fromJson).toList());
  }

  /// Salva o comentário do episódio; texto vazio apaga.
  Future<void> saveEpisodeComment({
    required String titleId,
    required String owner,
    required int season,
    required int episode,
    required String comment,
  }) async {
    final text = comment.trim();
    if (text.isEmpty) {
      await supabase
          .from('episode_comments')
          .delete()
          .eq('title_id', titleId)
          .eq('owner', owner)
          .eq('season', season)
          .eq('episode', episode);
      return;
    }
    await supabase.from('episode_comments').upsert({
      'title_id': titleId,
      'owner': owner,
      'season': season,
      'episode': episode,
      'comment': text,
    }, onConflict: 'title_id,owner,season,episode');
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
