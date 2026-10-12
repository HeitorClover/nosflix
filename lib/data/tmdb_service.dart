import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/tv_models.dart';

class TmdbSearchResult {
  final int id;
  final String mediaType; // 'movie' | 'tv'
  final String title;
  final String? originalTitle;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final int? releaseYear;
  final List<String> genres;

  const TmdbSearchResult({
    required this.id,
    required this.mediaType,
    required this.title,
    this.originalTitle,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.releaseYear,
    this.genres = const [],
  });
}

class TmdbCollection {
  final String name;
  final List<TmdbSearchResult> parts;
  const TmdbCollection({required this.name, required this.parts});
}

class TmdbService {
  static const _baseUrl = 'https://api.themoviedb.org/3';
  static const Map<int, String> _movieGenres = {
    28: 'Ação', 12: 'Aventura', 16: 'Animação', 35: 'Comédia', 80: 'Crime',
    99: 'Documentário', 18: 'Drama', 10751: 'Família', 14: 'Fantasia',
    36: 'História', 27: 'Terror', 10402: 'Música', 9648: 'Mistério',
    10749: 'Romance', 878: 'Ficção científica', 10770: 'Cinema TV',
    53: 'Thriller', 10752: 'Guerra', 37: 'Faroeste',
  };
  static const Map<int, String> _tvGenres = {
    10759: 'Ação e Aventura', 16: 'Animação', 35: 'Comédia', 80: 'Crime',
    99: 'Documentário', 18: 'Drama', 10751: 'Família', 10762: 'Infantil',
    9648: 'Mistério', 10763: 'News', 10764: 'Reality', 10765: 'Sci-Fi e Fantasia',
    10766: 'Novela', 10767: 'Talk', 10768: 'Guerra e Política', 37: 'Faroeste',
  };

  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  bool get isConfigured => _apiKey.isNotEmpty && _apiKey != 'your-tmdb-v3-api-key-here';

  Future<List<TmdbSearchResult>> search(String query) async {
    if (query.trim().isEmpty || !isConfigured) return [];

    // Busca em pt-BR e en-US e junta: a busca em pt-BR sozinha não acha
    // títulos pelo nome original (ex: "inception" -> "A Origem").
    final responses = await Future.wait([
      _searchIn(query, 'pt-BR'),
      _searchIn(query, 'en-US'),
    ]);

    final merged = <String, TmdbSearchResult>{};
    for (final r in responses[0]) {
      merged['${r.mediaType}:${r.id}'] = r;
    }
    for (final r in responses[1]) {
      merged.putIfAbsent('${r.mediaType}:${r.id}', () => r);
    }
    return merged.values.toList();
  }

  Future<Map<String, dynamic>?> _getJson(String path, [Map<String, String> params = const {}]) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: {'api_key': _apiKey, ...params});
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  DateTime? _date(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  /// Temporadas (sem a "temporada 0" de extras) e situação de exibição da série.
  Future<TvDetails> fetchTvDetails(int tmdbId) async {
    final data = await _getJson('/tv/$tmdbId', {'language': 'pt-BR'});
    if (data == null) return const TvDetails();
    final seasons = (data['seasons'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => (s['season_number'] as int? ?? 0) > 0)
        .map((s) => TvSeason(
              number: s['season_number'] as int,
              episodeCount: s['episode_count'] as int? ?? 0,
              name: s['name'] as String? ?? 'Temporada ${s['season_number']}',
            ))
        .toList();
    final next = data['next_episode_to_air'] as Map<String, dynamic>?;
    final last = data['last_episode_to_air'] as Map<String, dynamic>?;
    final status = data['status'] as String? ?? '';
    return TvDetails(
      seasons: seasons,
      airInfo: TvAirInfo(
        ended: status == 'Ended' || status == 'Canceled',
        nextAirDate: _date(next?['air_date']),
        nextSeason: next?['season_number'] as int?,
        nextEpisode: next?['episode_number'] as int?,
        lastAirDate: _date(last?['air_date']),
        lastSeason: seasons.isEmpty ? 0 : seasons.map((s) => s.number).reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  Future<List<TvEpisode>> fetchEpisodes(int tmdbId, int season) async {
    final data = await _getJson('/tv/$tmdbId/season/$season', {'language': 'pt-BR'});
    if (data == null) return [];
    return (data['episodes'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((e) => TvEpisode(
              number: e['episode_number'] as int,
              name: (e['name'] as String?)?.trim().isNotEmpty == true
                  ? e['name'] as String
                  : 'Episódio ${e['episode_number']}',
            ))
        .toList();
  }

  Future<WatchProviders> fetchWatchProviders(int tmdbId, String mediaType) async {
    final data = await _getJson('/$mediaType/$tmdbId/watch/providers');
    final br = (data?['results'] as Map<String, dynamic>?)?['BR'] as Map<String, dynamic>?;
    if (br == null) return const WatchProviders();
    List<WatchProvider> parse(String key) => (br[key] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((p) => WatchProvider(name: p['provider_name'] as String, logoPath: p['logo_path'] as String?))
        .toList();
    return WatchProviders(stream: parse('flatrate'), rent: parse('rent'), buy: parse('buy'));
  }

  /// Chave do vídeo do YouTube com o trailer (pt-BR, depois en-US), se houver.
  Future<String?> fetchTrailerKey(int tmdbId, String mediaType) async {
    for (final language in ['pt-BR', 'en-US']) {
      final data = await _getJson('/$mediaType/$tmdbId/videos', {'language': language});
      final videos = (data?['results'] as List? ?? []).cast<Map<String, dynamic>>().where(
            (v) => v['site'] == 'YouTube' && (v['type'] == 'Trailer' || v['type'] == 'Teaser'),
          );
      if (videos.isEmpty) continue;
      final sorted = videos.toList()
        ..sort((a, b) {
          int score(Map<String, dynamic> v) => (v['type'] == 'Trailer' ? 2 : 0) + (v['official'] == true ? 1 : 0);
          return score(b).compareTo(score(a));
        });
      return sorted.first['key'] as String?;
    }
    return null;
  }

  /// Coleção/saga a que o filme pertence, com todos os filmes dela. `null` se não houver.
  Future<TmdbCollection?> fetchCollection(int movieId) async {
    final movie = await _getJson('/movie/$movieId', {'language': 'pt-BR'});
    final belongs = movie?['belongs_to_collection'] as Map<String, dynamic>?;
    if (belongs == null) return null;
    final data = await _getJson('/collection/${belongs['id']}', {'language': 'pt-BR'});
    if (data == null) return null;
    final parts = (data['parts'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((p) => _fromJson({...p, 'media_type': 'movie'}))
        .toList()
      ..sort((a, b) => (a.releaseYear ?? 9999).compareTo(b.releaseYear ?? 9999));
    return TmdbCollection(name: data['name'] as String? ?? belongs['name'] as String, parts: parts);
  }

  Future<List<TmdbSearchResult>> _searchIn(String query, String language) async {
    final uri = Uri.parse('$_baseUrl/search/multi').replace(queryParameters: {
      'api_key': _apiKey,
      'query': query,
      'language': language,
      'include_adult': 'false',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erro TMDB (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['results'] as List? ?? [])
        .where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv')
        .map((r) => _fromJson(r as Map<String, dynamic>))
        .toList();
  }

  TmdbSearchResult _fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String;
    final isMovie = mediaType == 'movie';
    final dateStr = (isMovie ? json['release_date'] : json['first_air_date']) as String?;
    final year = (dateStr != null && dateStr.length >= 4) ? int.tryParse(dateStr.substring(0, 4)) : null;
    final genreIds = (json['genre_ids'] as List? ?? []).cast<int>();
    final genreMap = isMovie ? _movieGenres : _tvGenres;
    final genres = genreIds.map((id) => genreMap[id]).whereType<String>().toList();

    return TmdbSearchResult(
      id: json['id'] as int,
      mediaType: mediaType,
      title: (isMovie ? json['title'] : json['name']) as String? ?? 'Sem título',
      originalTitle: (isMovie ? json['original_title'] : json['original_name']) as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      overview: json['overview'] as String?,
      releaseYear: year,
      genres: genres,
    );
  }
}
