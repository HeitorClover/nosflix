import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

    final uri = Uri.parse('$_baseUrl/search/multi').replace(queryParameters: {
      'api_key': _apiKey,
      'query': query,
      'language': 'pt-BR',
      'include_adult': 'false',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erro TMDB (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List? ?? [])
        .where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv')
        .map((r) => _fromJson(r as Map<String, dynamic>))
        .toList();

    return results;
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
