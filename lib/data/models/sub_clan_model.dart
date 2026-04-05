import '../../domain/entities/sub_clan.dart';

/// Sub-clan data model.
class SubClanModel {
  final int id;
  final int familyId;
  final String subName;
  final DateTime? createdAt;
  final String? familyName;

  const SubClanModel({
    required this.id,
    required this.familyId,
    required this.subName,
    this.createdAt,
    this.familyName,
  });

  factory SubClanModel.fromJson(Map<String, dynamic> json) {
    return SubClanModel(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      subName: json['sub_name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      familyName: json['families'] != null
          ? (json['families'] as Map<String, dynamic>)['family_name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'sub_name': subName,
    };
  }

  SubClan toEntity() {
    return SubClan(
      id: id,
      familyId: familyId,
      subName: subName,
      createdAt: createdAt,
      familyName: familyName,
    );
  }

  factory SubClanModel.fromEntity(SubClan entity) {
    return SubClanModel(
      id: entity.id,
      familyId: entity.familyId,
      subName: entity.subName,
      createdAt: entity.createdAt,
      familyName: entity.familyName,
    );
  }

  Map<String, dynamic> toHiveMap() => {
        'id': id,
        'family_id': familyId,
        'sub_name': subName,
        'family_name': familyName,
      };

  factory SubClanModel.fromHiveMap(Map<dynamic, dynamic> map) {
    return SubClanModel(
      id: map['id'] as int,
      familyId: map['family_id'] as int,
      subName: map['sub_name'] as String,
      familyName: map['family_name'] as String?,
    );
  }
}
