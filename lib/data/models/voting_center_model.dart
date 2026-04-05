import '../../domain/entities/voting_center.dart';

/// Voting center data model.
class VotingCenterModel {
  final int id;
  final String centerName;
  final DateTime? createdAt;

  const VotingCenterModel({
    required this.id,
    required this.centerName,
    this.createdAt,
  });

  factory VotingCenterModel.fromJson(Map<String, dynamic> json) {
    return VotingCenterModel(
      id: json['id'] as int,
      centerName: json['center_name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'center_name': centerName,
    };
  }

  VotingCenter toEntity() {
    return VotingCenter(id: id, centerName: centerName, createdAt: createdAt);
  }

  factory VotingCenterModel.fromEntity(VotingCenter entity) {
    return VotingCenterModel(
      id: entity.id,
      centerName: entity.centerName,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toHiveMap() => {'id': id, 'center_name': centerName};

  factory VotingCenterModel.fromHiveMap(Map<dynamic, dynamic> map) {
    return VotingCenterModel(
      id: map['id'] as int,
      centerName: map['center_name'] as String,
    );
  }
}
