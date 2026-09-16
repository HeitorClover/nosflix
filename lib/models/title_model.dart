import 'watch_status.dart';

class TitleModel {
  final String id;
  final int? tmdbId;
  final String mediaType; // 'movie' | 'tv'
  final TitleCategory category;
  final String title;
  final String? originalTitle;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final int? releaseYear;
  final List<String> genres;
  final WatchStatus status;
  final String? recommendedBy;
  final String addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TitleModel({
    required this.id,
    this.tmdbId,
    required this.mediaType,
    required this.category,
    required this.title,
    this.originalTitle,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.releaseYear,
    this.genres = const [],
    required this.status,
    this.recommendedBy,
    required this.addedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TitleModel.fromJson(Map<String, dynamic> json) {
    return TitleModel(
      id: json['id'] as String,
      tmdbId: json['tmdb_id'] as int?,
      mediaType: json['media_type'] as String,
      category: TitleCategoryX.fromValue(json['category'] as String? ?? 'outro'),
      title: json['title'] as String,
      originalTitle: json['original_title'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      overview: json['overview'] as String?,
      releaseYear: json['release_year'] as int?,
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      status: WatchStatusX.fromValue(json['status'] as String? ?? 'quero_ver'),
      recommendedBy: json['recommended_by'] as String?,
      addedBy: json['added_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'tmdb_id': tmdbId,
        'media_type': mediaType,
        'category': category.value,
        'title': title,
        'original_title': originalTitle,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'overview': overview,
        'release_year': releaseYear,
        'genres': genres,
        'status': status.value,
        'recommended_by': recommendedBy,
        'added_by': addedBy,
      };

  static const _posterBase = 'https://image.tmdb.org/t/p/w500';
  static const _backdropBase = 'https://image.tmdb.org/t/p/w780';

  String? get posterUrl => posterPath == null ? null : '$_posterBase$posterPath';
  String? get backdropUrl => backdropPath == null ? null : '$_backdropBase$backdropPath';
}
