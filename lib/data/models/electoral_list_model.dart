import '../../domain/entities/electoral_list.dart';

class ElectoralListModel {
  final int id;
  final String listName;
  final DateTime? createdAt;

  const ElectoralListModel({
    required this.id,
    required this.listName,
    this.createdAt,
  });

  factory ElectoralListModel.fromJson(Map<String, dynamic> json) {
    return ElectoralListModel(
      id: json['id'] as int,
      listName: json['list_name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'list_name': listName,
    };
  }

  ElectoralList toEntity() {
    return ElectoralList(
      id: id,
      listName: listName,
      createdAt: createdAt,
    );
  }

  factory ElectoralListModel.fromEntity(ElectoralList entity) {
    return ElectoralListModel(
      id: entity.id,
      listName: entity.listName,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toHiveMap() => {
        'id': id,
        'list_name': listName,
      };

  factory ElectoralListModel.fromHiveMap(Map<dynamic, dynamic> map) {
    return ElectoralListModel(
      id: map['id'] as int,
      listName: map['list_name'] as String,
    );
  }
}
