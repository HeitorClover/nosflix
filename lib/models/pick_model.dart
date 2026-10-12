/// Escolha de um título para a noite de cinema (cada pessoa tem até 3).
class PickModel {
  final String id;
  final String owner; // 'heitor' | 'leticia'
  final String titleId;

  const PickModel({required this.id, required this.owner, required this.titleId});

  factory PickModel.fromJson(Map<String, dynamic> json) => PickModel(
        id: json['id'] as String,
        owner: json['owner'] as String,
        titleId: json['title_id'] as String,
      );
}
