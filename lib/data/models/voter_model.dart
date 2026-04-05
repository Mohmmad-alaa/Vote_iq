import '../../domain/entities/voter.dart';

/// Voter data model — handles JSON serialization for Supabase.
class VoterModel {
  final String voterSymbol;
  final String? firstName;
  final String? fatherName;
  final String? grandfatherName;
  final int? familyId;
  final int? subClanId;
  final int? centerId;
  final int? listId;
  final int? candidateId;
  final String status;
  final String? refusalReason;
  final DateTime? updatedAt;
  final String? updatedBy;

  // From joins
  final String? familyName;
  final String? subClanName;
  final String? centerName;
  final String? listName;
  final String? candidateName;

  const VoterModel({
    required this.voterSymbol,
    this.firstName,
    this.fatherName,
    this.grandfatherName,
    this.familyId,
    this.subClanId,
    this.centerId,
    this.listId,
    this.candidateId,
    this.status = 'لم يصوت',
    this.refusalReason,
    this.updatedAt,
    this.updatedBy,
    this.familyName,
    this.subClanName,
    this.centerName,
    this.listName,
    this.candidateName,
  });

  /// Parse from Supabase JSON response.
  factory VoterModel.fromJson(Map<String, dynamic> json) {
    final familyJoin = json['families'] as Map<String, dynamic>?;
    final subClanJoin = json['sub_clans'] as Map<String, dynamic>?;
    final centerJoin = json['voting_centers'] as Map<String, dynamic>?;
    final listJoin = json['electoral_lists'] as Map<String, dynamic>?;
    final candidateJoin = json['candidates'] as Map<String, dynamic>?;
    final candidateListJoin =
        candidateJoin?['electoral_lists'] as Map<String, dynamic>?;

    return VoterModel(
      voterSymbol: json['voter_symbol'] as String,
      firstName: json['first_name'] as String?,
      fatherName: json['father_name'] as String?,
      grandfatherName: json['grandfather_name'] as String?,
      familyId: json['family_id'] as int?,
      subClanId: json['sub_clan_id'] as int?,
      centerId: json['center_id'] as int?,
      listId: json['list_id'] as int?,
      candidateId: json['candidate_id'] as int?,
      status: (json['status'] as String?) ?? 'لم يصوت',
      refusalReason: json['refusal_reason'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
      // Nested join data
      familyName: familyJoin?['family_name'] as String?,
      subClanName: subClanJoin?['sub_name'] as String?,
      centerName: centerJoin?['center_name'] as String?,
      listName: (listJoin?['list_name'] ?? candidateListJoin?['list_name'])
          as String?,
      candidateName: candidateJoin?['candidate_name'] as String?,
    );
  }

  /// Serialize to JSON for Supabase insert/update.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'voter_symbol': voterSymbol,
      'status': status,
    };
    if (firstName != null) map['first_name'] = firstName;
    if (fatherName != null) map['father_name'] = fatherName;
    if (grandfatherName != null) map['grandfather_name'] = grandfatherName;
    if (familyId != null) map['family_id'] = familyId;
    if (subClanId != null) map['sub_clan_id'] = subClanId;
    if (centerId != null) map['center_id'] = centerId;
    if (listId != null) map['list_id'] = listId;
    if (candidateId != null) map['candidate_id'] = candidateId;
    if (refusalReason != null) map['refusal_reason'] = refusalReason;
    if (updatedBy != null) map['updated_by'] = updatedBy;
    return map;
  }

  /// Convert to domain entity.
  Voter toEntity() {
    return Voter(
      voterSymbol: voterSymbol,
      firstName: firstName,
      fatherName: fatherName,
      grandfatherName: grandfatherName,
      familyId: familyId,
      subClanId: subClanId,
      centerId: centerId,
      listId: listId,
      candidateId: candidateId,
      status: status,
      refusalReason: refusalReason,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      familyName: familyName,
      subClanName: subClanName,
      centerName: centerName,
      listName: listName,
      candidateName: candidateName,
    );
  }

  /// Create from domain entity.
  factory VoterModel.fromEntity(Voter entity) {
    return VoterModel(
      voterSymbol: entity.voterSymbol,
      firstName: entity.firstName,
      fatherName: entity.fatherName,
      grandfatherName: entity.grandfatherName,
      familyId: entity.familyId,
      subClanId: entity.subClanId,
      centerId: entity.centerId,
      listId: entity.listId,
      candidateId: entity.candidateId,
      status: entity.status,
      refusalReason: entity.refusalReason,
      updatedAt: entity.updatedAt,
      updatedBy: entity.updatedBy,
      familyName: entity.familyName,
      subClanName: entity.subClanName,
      centerName: entity.centerName,
      listName: entity.listName,
      candidateName: entity.candidateName,
    );
  }

  /// Serialize for Hive local cache storage.
  Map<String, dynamic> toHiveMap() {
    final searchBlob = [voterSymbol, firstName, fatherName, grandfatherName, familyName, subClanName, listName, candidateName]
        .whereType<String>()
        .join(' ')
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
        .trim()
        .toLowerCase();

    return {
      'voter_symbol': voterSymbol,
      'first_name': firstName,
      'father_name': fatherName,
      'grandfather_name': grandfatherName,
      'family_id': familyId,
      'sub_clan_id': subClanId,
      'center_id': centerId,
      'list_id': listId,
      'candidate_id': candidateId,
      'status': status,
      'refusal_reason': refusalReason,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
      'family_name': familyName,
      'sub_clan_name': subClanName,
      'center_name': centerName,
      'list_name': listName,
      'candidate_name': candidateName,
      'search_blob': searchBlob,
    };
  }

  /// Parse from Hive local cache.
  factory VoterModel.fromHiveMap(Map<dynamic, dynamic> map) {
    return VoterModel(
      voterSymbol: map['voter_symbol'] as String,
      firstName: map['first_name'] as String?,
      fatherName: map['father_name'] as String?,
      grandfatherName: map['grandfather_name'] as String?,
      familyId: map['family_id'] as int?,
      subClanId: map['sub_clan_id'] as int?,
      centerId: map['center_id'] as int?,
      listId: map['list_id'] as int?,
      candidateId: map['candidate_id'] as int?,
      status: (map['status'] as String?) ?? 'لم يصوت',
      refusalReason: map['refusal_reason'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      updatedBy: map['updated_by'] as String?,
      familyName: map['family_name'] as String?,
      subClanName: map['sub_clan_name'] as String?,
      centerName: map['center_name'] as String?,
      listName: map['list_name'] as String?,
      candidateName: map['candidate_name'] as String?,
    );
  }
}
