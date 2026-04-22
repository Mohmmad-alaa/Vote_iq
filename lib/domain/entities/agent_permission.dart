import 'package:equatable/equatable.dart';

/// Agent permission entity — defines what data a delegate can access.
///
/// | family_id | sub_clan_id | Meaning                          |
/// |-----------|-------------|----------------------------------|
/// | NULL      | NULL        | All data (all families)          |
/// | 1         | NULL        | All sub-clans of family 1        |
/// | 1         | 3           | Only sub-clan 3 in family 1      |
class AgentPermission extends Equatable {
  final int id;
  final String agentId;
  final int? familyId;
  final int? subClanId;
  final bool isManager;

  // Resolved names
  final String? familyName;
  final String? subClanName;

  const AgentPermission({
    required this.id,
    required this.agentId,
    this.familyId,
    this.subClanId,
    this.isManager = false,
    this.familyName,
    this.subClanName,
  });

  /// Whether this permission grants access to all families.
  bool get isGlobalAccess => familyId == null && subClanId == null;

  /// Whether this permission grants access to an entire family.
  bool get isFamilyLevel => familyId != null && subClanId == null;

  /// Whether this permission is scoped to a specific sub-clan.
  bool get isSubClanLevel => familyId != null && subClanId != null;

  @override
  List<Object?> get props => [id, agentId, familyId, subClanId, isManager];
}
