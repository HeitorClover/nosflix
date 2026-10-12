class EpisodeCommentModel {
  final String id;
  final String titleId;
  final String owner; // 'heitor' | 'leticia'
  final int season;
  final int episode;
  final String comment;
  final DateTime updatedAt;

  const EpisodeCommentModel({
    required this.id,
    required this.titleId,
    required this.owner,
    required this.season,
    required this.episode,
    required this.comment,
    required this.updatedAt,
  });

  factory EpisodeCommentModel.fromJson(Map<String, dynamic> json) {
    return EpisodeCommentModel(
      id: json['id'] as String,
      titleId: json['title_id'] as String,
      owner: json['owner'] as String,
      season: json['season'] as int,
      episode: json['episode'] as int,
      comment: json['comment'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
