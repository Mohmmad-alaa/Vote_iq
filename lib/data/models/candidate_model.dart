import '../../domain/entities/candidate.dart';

class CandidateModel {
  final int id;
  final String candidateName;
  final int? listId;
  final DateTime? createdAt;
  final String? listName;

  const CandidateModel({
    required this.id,
    required this.candidateName,
    this.listId,
    this.createdAt,
    this.listName,
  });

  factory CandidateModel.fromJson(Map<String, dynamic> json) {
    final listJoin = json['electoral_lists'] as Map<String, dynamic>?;

    return CandidateModel(
      id: json['id'] as int,
      candidateName: json['candidate_name'] as String,
      listId: json['list_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      listName: listJoin?['list_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'candidate_name': candidateName,
      'list_id': listId,
    };
  }

  Candidate toEntity() {
    return Candidate(
      id: id,
      candidateName: candidateName,
      listId: listId,
      createdAt: createdAt,
      listName: listName,
    );
  }

  factory CandidateModel.fromEntity(Candidate entity) {
    return CandidateModel(
      id: entity.id,
      candidateName: entity.candidateName,
      listId: entity.listId,
      createdAt: entity.createdAt,
      listName: entity.listName,
    );
  }

  Map<String, dynamic> toHiveMap() => {
        'id': id,
        'candidate_name': candidateName,
        'list_id': listId,
        'list_name': listName,
      };

  factory CandidateModel.fromHiveMap(Map<dynamic, dynamic> map) {
    return CandidateModel(
      id: map['id'] as int,
      candidateName: map['candidate_name'] as String,
      listId: map['list_id'] as int?,
      listName: map['list_name'] as String?,
    );
  }
}
