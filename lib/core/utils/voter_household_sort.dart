import '../../domain/entities/voter.dart';

const String householdRoleHusband = 'husband';
const String householdRoleWife = 'wife';
const String householdRoleChild = 'child';
const String householdRoleOther = 'other';

String? normalizeHouseholdRole(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  switch (normalized) {
    case 'husband':
    case 'head':
    case 'head_of_household':
    case 'زوج':
    case 'الزوج':
    case 'رب المنزل':
    case 'رب الاسرة':
    case 'رب الأسرة':
    case 'رب البيت':
      return householdRoleHusband;
    case 'wife':
    case 'spouse':
    case 'زوجة':
    case 'الزوجة':
      return householdRoleWife;
    case 'child':
    case 'children':
    case 'son':
    case 'daughter':
    case 'ابن':
    case 'إبن':
    case 'ابنة':
    case 'بنت':
    case 'ولد':
    case 'طفل':
    case 'طفلة':
    case 'الاولاد':
    case 'الأولاد':
      return householdRoleChild;
    case 'other':
    case 'اخرى':
    case 'أخرى':
      return householdRoleOther;
    default:
      return normalized;
  }
}

int householdRolePriority(String? value) {
  switch (normalizeHouseholdRole(value)) {
    case householdRoleHusband:
      return 0;
    case householdRoleWife:
      return 1;
    case householdRoleChild:
      return 2;
    default:
      return 3;
  }
}

String? normalizeHouseholdGroup(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int compareVotersByHousehold(Voter a, Voter b) {
  return _compareHouseholdAware(
    familyIdA: a.familyId,
    familyIdB: b.familyId,
    familyNameA: a.familyName,
    familyNameB: b.familyName,
    householdGroupA: a.householdGroup,
    householdGroupB: b.householdGroup,
    householdRoleA: a.householdRole,
    householdRoleB: b.householdRole,
    firstNameA: a.firstName,
    firstNameB: b.firstName,
    fatherNameA: a.fatherName,
    fatherNameB: b.fatherName,
    grandfatherNameA: a.grandfatherName,
    grandfatherNameB: b.grandfatherName,
    symbolA: a.voterSymbol,
    symbolB: b.voterSymbol,
  );
}

int compareVoterMapsByHousehold(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  return _compareHouseholdAware(
    familyIdA: a['family_id'] as int?,
    familyIdB: b['family_id'] as int?,
    familyNameA: a['family_name'] as String?,
    familyNameB: b['family_name'] as String?,
    householdGroupA: a['household_group'] as String?,
    householdGroupB: b['household_group'] as String?,
    householdRoleA: a['household_role'] as String?,
    householdRoleB: b['household_role'] as String?,
    firstNameA: a['first_name'] as String?,
    firstNameB: b['first_name'] as String?,
    fatherNameA: a['father_name'] as String?,
    fatherNameB: b['father_name'] as String?,
    grandfatherNameA: a['grandfather_name'] as String?,
    grandfatherNameB: b['grandfather_name'] as String?,
    symbolA: a['voter_symbol'] as String? ?? '',
    symbolB: b['voter_symbol'] as String? ?? '',
  );
}

int _compareHouseholdAware({
  required int? familyIdA,
  required int? familyIdB,
  required String? familyNameA,
  required String? familyNameB,
  required String? householdGroupA,
  required String? householdGroupB,
  required String? householdRoleA,
  required String? householdRoleB,
  required String? firstNameA,
  required String? firstNameB,
  required String? fatherNameA,
  required String? fatherNameB,
  required String? grandfatherNameA,
  required String? grandfatherNameB,
  required String symbolA,
  required String symbolB,
}) {
  final familyIdCmp = _compareNullableInts(familyIdA, familyIdB);
  if (familyIdCmp != 0) {
    return familyIdCmp;
  }

  final familyNameCmp = _compareText(familyNameA, familyNameB);
  if (familyNameCmp != 0) {
    return familyNameCmp;
  }

  final groupCmp = _compareText(
    normalizeHouseholdGroup(householdGroupA) ?? symbolA,
    normalizeHouseholdGroup(householdGroupB) ?? symbolB,
  );
  if (groupCmp != 0) {
    return groupCmp;
  }

  final roleCmp = householdRolePriority(householdRoleA).compareTo(
    householdRolePriority(householdRoleB),
  );
  if (roleCmp != 0) {
    return roleCmp;
  }

  final fatherCmp = _compareText(fatherNameA, fatherNameB);
  if (fatherCmp != 0) {
    return fatherCmp;
  }

  final grandfatherCmp = _compareText(grandfatherNameA, grandfatherNameB);
  if (grandfatherCmp != 0) {
    return grandfatherCmp;
  }

  final firstCmp = _compareText(firstNameA, firstNameB);
  if (firstCmp != 0) {
    return firstCmp;
  }

  return _compareText(symbolA, symbolB);
}

int _compareNullableInts(int? a, int? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}

int _compareText(String? a, String? b) {
  final left = (a ?? '').trim();
  final right = (b ?? '').trim();
  return left.compareTo(right);
}
