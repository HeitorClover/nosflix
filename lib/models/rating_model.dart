class RatingModel {
  final String id;
  final String titleId;
  final String owner; // 'heitor' | 'leticia'
  final double? rating; // 0-10
  final String? comment;
  final DateTime? watchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RatingModel({
    required this.id,
    required this.titleId,
    required this.owner,
    this.rating,
    this.comment,
    this.watchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String,
      titleId: json['title_id'] as String,
      owner: json['owner'] as String,
      rating: (json['rating'] as num?)?.toDouble(),
      comment: json['comment'] as String?,
      watchedAt: json['watched_at'] == null ? null : DateTime.parse(json['watched_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toUpsertJson(String titleId) => {
        'title_id': titleId,
        'owner': owner,
        'rating': rating,
        'comment': comment,
        'watched_at': watchedAt?.toIso8601String().split('T').first,
      };
}
