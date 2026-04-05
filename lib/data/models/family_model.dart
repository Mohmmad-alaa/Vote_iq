import '../../domain/entities/family.dart';

/// Family data model.
class FamilyModel {
  final int id;
  final String familyName;
  final DateTime? createdAt;

  const FamilyModel({
    required this.id,
    required this.familyName,
    this.createdAt,
  });

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['id'] as int,
      familyName: json['family_name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_name': familyName,
    };
  }

  Family toEntity() {
    return Family(id: id, familyName: familyName, createdAt: createdAt);
  }

  factory FamilyModel.fromEntity(Family entity) {
    return FamilyModel(
      id: entity.id,
      familyName: entity.familyName,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toHiveMap() => {'id': id, 'family_name': familyName};

  factory FamilyModel.fromHiveMap(Map<dynamic, dynamic> map) {
    return FamilyModel(
      id: map['id'] as int,
      familyName: map['family_name'] as String,
    );
  }
}
