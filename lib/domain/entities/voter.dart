import 'package:equatable/equatable.dart';

/// Voter entity — pure domain object, no Supabase/Hive dependency.
class Voter extends Equatable {
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

  // ── Resolved names (populated from joins) ──
  final String? familyName;
  final String? subClanName;
  final String? centerName;
  final String? listName;
  final String? candidateName;

  const Voter({
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

  /// Full name: first + father + grandfather + family.
  String get fullName {
    return [firstName, fatherName, grandfatherName, familyName]
        .where((n) => n != null && n.isNotEmpty)
        .join(' ');
  }

  /// Whether this voter is in "voted" status.
  bool get hasVoted => status == 'تم التصويت';

  /// Whether this voter refused.
  bool get hasRefused => status == 'رفض';

  /// Create a copy with updated fields.
  Voter copyWith({
    String? voterSymbol,
    String? firstName,
    String? fatherName,
    String? grandfatherName,
    int? familyId,
    int? subClanId,
    int? centerId,
    int? listId,
    int? candidateId,
    String? status,
    String? refusalReason,
    DateTime? updatedAt,
    String? updatedBy,
    String? familyName,
    String? subClanName,
    String? centerName,
    String? listName,
    String? candidateName,
  }) {
    return Voter(
      voterSymbol: voterSymbol ?? this.voterSymbol,
      firstName: firstName ?? this.firstName,
      fatherName: fatherName ?? this.fatherName,
      grandfatherName: grandfatherName ?? this.grandfatherName,
      familyId: familyId ?? this.familyId,
      subClanId: subClanId ?? this.subClanId,
      centerId: centerId ?? this.centerId,
      listId: listId ?? this.listId,
      candidateId: candidateId ?? this.candidateId,
      status: status ?? this.status,
      refusalReason: refusalReason ?? this.refusalReason,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      familyName: familyName ?? this.familyName,
      subClanName: subClanName ?? this.subClanName,
      centerName: centerName ?? this.centerName,
      listName: listName ?? this.listName,
      candidateName: candidateName ?? this.candidateName,
    );
  }

  @override
  List<Object?> get props => [
        voterSymbol,
        firstName,
        fatherName,
        grandfatherName,
        familyId,
        subClanId,
        centerId,
        listId,
        candidateId,
        status,
        refusalReason,
        updatedAt,
        updatedBy,
        listName,
        candidateName,
      ];
}
