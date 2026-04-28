import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/utils/voter_household_sort.dart';
import '../../../data/datasources/local/local_voter_datasource.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/voter.dart';
import '../../lookup/cubit/lookup_cubit.dart';
import '../../lookup/cubit/lookup_state.dart';
import '../../common_widgets/status_badge.dart';
import '../cubit/voters_cubit.dart';
import '../cubit/voters_state.dart';

class VoterDetailScreen extends StatefulWidget {
  final Voter voter;

  const VoterDetailScreen({super.key, required this.voter});

  @override
  State<VoterDetailScreen> createState() => _VoterDetailScreenState();
}

class _VoterDetailScreenState extends State<VoterDetailScreen> {
  late Voter _voter;
  Voter? _cachedHead;

  bool get _isHusband =>
      normalizeHouseholdRole(_voter.householdRole) == householdRoleHusband;



  Future<void> _loadHouseholdHead() async {
    if (_isHusband) return;
    final householdGroup = normalizeHouseholdGroup(_voter.householdGroup);
    if (householdGroup == null || householdGroup.isEmpty) return;

    final localDs = sl<LocalVoterDatasource>();
    final model = await localDs.getCachedVoter(householdGroup);
    if (model != null && mounted) {
      setState(() => _cachedHead = model.toEntity());
    }
  }

  List<Voter> _householdMembers(BuildContext context) {
    final state = context.read<VotersCubit>().state;
    if (state is! VotersLoaded) {
      return const <Voter>[];
    }

    final householdGroup = normalizeHouseholdGroup(_voter.householdGroup);
    if (householdGroup == null || householdGroup.isEmpty) {
      return const <Voter>[];
    }

    final members = state.voters.where((candidate) {
      if (candidate.voterSymbol == _voter.voterSymbol) {
        return false;
      }
      return normalizeHouseholdGroup(candidate.householdGroup) == householdGroup;
    }).toList();

    members.sort(compareVotersByHousehold);
    return members;
  }

  bool _hasLinkedHousehold(BuildContext context) {
    return _householdMembers(context).isNotEmpty;
  }

  Voter? _householdHead(BuildContext context) {
    if (_isHusband) {
      return _voter;
    }

    final householdGroup = normalizeHouseholdGroup(_voter.householdGroup);
    if (householdGroup == null || householdGroup.isEmpty) {
      return null;
    }

    // First check in loaded paginated voters
    final state = context.read<VotersCubit>().state;
    if (state is VotersLoaded) {
      for (final candidate in state.voters) {
        if (candidate.voterSymbol == householdGroup) {
          return candidate;
        }
      }
    }

    // Fallback to cached head from local Hive
    return _cachedHead;
  }

  void _openRelativeDetails(BuildContext context, Voter relative) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<VotersCubit>()),
            BlocProvider.value(value: context.read<LookupCubit>()),
          ],
          child: VoterDetailScreen(voter: relative),
        ),
      ),
    );
  }

  String _householdRoleLabel(String? role) {
    switch (normalizeHouseholdRole(role)) {
      case householdRoleWife:
        return 'الزوجة';
      case householdRoleChild:
        return 'ابن/ابنة';
      case householdRoleHusband:
        return 'الزوج';
      default:
        return 'فرد من العائلة';
    }
  }

  String _householdRoleDetailsLabel() {
    final normalizedRole = normalizeHouseholdRole(_voter.householdRole);
    if (normalizedRole == null || normalizedRole.isEmpty) {
      return 'غير محدد';
    }
    if (normalizedRole == householdRoleHusband) {
      return 'رب المنزل';
    }
    return _householdRoleLabel(normalizedRole);
  }

  String _householdRelationWithHeadLabel(BuildContext context) {
    final normalizedRole = normalizeHouseholdRole(_voter.householdRole);
    if (normalizedRole == null || normalizedRole.isEmpty) {
      return 'غير محدد';
    }

    if (normalizedRole == householdRoleHusband) {
      return 'رب الأسرة';
    }

    final householdGroup = normalizeHouseholdGroup(_voter.householdGroup);
    final head = _householdHead(context);
    final headName = head?.fullName.trim();
    final roleLabel = _householdRoleLabel(normalizedRole);
    
    if (headName != null && headName.isNotEmpty) {
      return '$roleLabel - $headName';
    } else if (householdGroup != null && householdGroup.isNotEmpty) {
      return '$roleLabel - $householdGroup';
    }

    return roleLabel;
  }



  String _householdHeadName(BuildContext context) {
    final head = _householdHead(context);
    final name = head?.fullName.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'غير محدد';
  }

  String _resolvedListName(BuildContext context) {
    if (_voter.listName != null && _voter.listName!.isNotEmpty) {
      return _voter.listName!;
    }

    final lookupState = context.read<LookupCubit>().state;
    if (lookupState is LookupLoaded && _voter.listId != null) {
      for (final item in lookupState.electoralLists) {
        if (item.id == _voter.listId) {
          return item.listName;
        }
      }
    }

    return 'غير محدد';
  }

  String _resolvedCandidateName(BuildContext context) {
    if (_voter.candidateName != null && _voter.candidateName!.isNotEmpty) {
      return _voter.candidateName!;
    }

    final lookupState = context.read<LookupCubit>().state;
    if (lookupState is LookupLoaded && _voter.candidateId != null) {
      for (final item in lookupState.candidates) {
        if (item.id == _voter.candidateId) {
          return item.candidateName;
        }
      }
    }

    return 'غير محدد';
  }

  @override
  void initState() {
    super.initState();
    _voter = widget.voter;
    _loadHouseholdHead();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VotersCubit, VotersState>(
      listener: (context, state) {
        if (state is VotersLoaded) {
          final updatedVoter = state.voters.firstWhere(
            (v) => v.voterSymbol == _voter.voterSymbol,
            orElse: () => _voter,
          );
          setState(() {
            _voter = updatedVoter;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الناخب')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _voter.fullName.isNotEmpty
                            ? _voter.fullName
                            : 'بدون اسم',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الرقم الانتخابي: ${_voter.voterSymbol}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StatusBadge(status: _voter.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات الناخب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.family_restroom,
                        'العائلة',
                        _voter.familyName ?? 'غير محدد',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.account_tree_outlined,
                        'الفرع',
                        _voter.subClanName ?? 'غير محدد',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'مركز الاقتراع',
                        _voter.centerName ?? 'غير محدد',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.people_outline,
                        'صلة القرابة',
                        _householdRelationWithHeadLabel(context),
                      ),


                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.how_to_vote_outlined,
                        'القائمة الانتخابية',
                        _resolvedListName(context),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.person_outline,
                        'المرشح',
                        _resolvedCandidateName(context),
                      ),
                    ],
                  ),
                ),
              ),
              if (_hasLinkedHousehold(context)) ...[
                const SizedBox(height: 16),
                _buildHouseholdCard(context),
              ],
              const SizedBox(height: 24),
              const Text(
                'تحديث الحالة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _voter.status == AppConstants.statusVoted
                          ? null
                          : () => _showVoteDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusVoted,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'صوّت',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _voter.status == AppConstants.statusRefused
                          ? null
                          : () => _showRefusalDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusRefused,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'رفض',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _voter.status == AppConstants.statusNotFound
                      ? null
                      : () => _updateStatus(context, AppConstants.statusNotFound),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusNotFound,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.person_off_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'غير موجود',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    
  }


  Widget _buildHouseholdCard(BuildContext context) {
    final members = _householdMembers(context);
    final householdHeads = members
        .where(
          (member) =>
              normalizeHouseholdRole(member.householdRole) == householdRoleHusband,
        )
        .toList(growable: false);
    final wives = members
        .where(
          (member) =>
              normalizeHouseholdRole(member.householdRole) == householdRoleWife,
        )
        .toList(growable: false);
    final children = members
        .where(
          (member) =>
              normalizeHouseholdRole(member.householdRole) == householdRoleChild,
        )
        .toList(growable: false);
    final others = members
        .where((member) {
          final role = normalizeHouseholdRole(member.householdRole);
          return role != householdRoleHusband &&
              role != householdRoleWife &&
              role != householdRoleChild;
        })
        .toList(growable: false);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'العائلة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'الزوجة والأبناء المرتبطون برب المنزل هذا',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const Divider(height: 24),
            if (members.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'لا توجد زوجة أو أبناء مرتبطون بهذا الزوج حاليًا.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (householdHeads.isNotEmpty) ...[
              const Text(
                'رب المنزل',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...householdHeads.map(
                (head) => _buildHouseholdMemberTile(context, head),
              ),
            ],
            if (householdHeads.isNotEmpty &&
                (wives.isNotEmpty || children.isNotEmpty || others.isNotEmpty))
              const SizedBox(height: 12),
            if (wives.isNotEmpty) ...[
              const Text(
                'الزوجة',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...wives.map((wife) => _buildHouseholdMemberTile(context, wife)),
            ],
            if (wives.isNotEmpty && (children.isNotEmpty || others.isNotEmpty))
              const SizedBox(height: 12),
            if (children.isNotEmpty) ...[
              const Text(
                'الأبناء',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...children.map(
                (child) => _buildHouseholdMemberTile(context, child),
              ),
            ],
            if (children.isNotEmpty && others.isNotEmpty)
              const SizedBox(height: 12),
            if (others.isNotEmpty) ...[
              const Text(
                'أفراد آخرون',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...others.map(
                (member) => _buildHouseholdMemberTile(context, member),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdMemberTile(BuildContext context, Voter member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRelativeDetails(context, member),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.family_restroom,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName.isNotEmpty
                          ? member.fullName
                          : member.voterSymbol,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الرقم: ${member.voterSymbol}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _householdRoleLabel(member.householdRole),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String newStatus, {
    String? refusalReason,
    int? listId,
    List<int>? candidateIds,
  }) async {
    final cubit = context.read<VotersCubit>();
    final updatedVoter = await cubit.updateVoterStatus(
      voterSymbol: _voter.voterSymbol,
      newStatus: newStatus,
      refusalReason: refusalReason,
      listId: listId,
      candidateId: (candidateIds != null && candidateIds.isNotEmpty)
          ? candidateIds.first
          : null,
    );

    if (!mounted) return;

    if (updatedVoter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل تحديث حالة الناخب'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _voter = updatedVoter;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحديث الحالة بنجاح: $newStatus'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    // Save candidates in background — don't block UI
    if (candidateIds != null && candidateIds.length <= 5) {
      final messengerRef = ScaffoldMessenger.of(context);
      cubit.saveVoterCandidates(
        voterSymbol: _voter.voterSymbol,
        candidateIds: candidateIds,
      ).then((error) {
        if (error != null && mounted) {
          messengerRef.showSnackBar(
            SnackBar(
              content: Text(
                'تم تسجيل التصويت، لكن فشل حفظ المرشحين: $error',
              ),
              backgroundColor: AppColors.statusRefused,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Future<void> _showVoteDialog(BuildContext context) async {
    final screenContext = context;
    final lookupCubit = context.read<LookupCubit>();
    if (lookupCubit.state is! LookupLoaded) {
      await lookupCubit.loadAll();
    }

    if (!mounted) return;

    final lookupState = lookupCubit.state;
    if (lookupState is! LookupLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل القوائم والمرشحين'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    var selectedListId = _voter.listId;
    final Set<int> selectedCandidateIds = {};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogStateContext, setDialogState) {
            final filteredCandidates = selectedListId == null
                ? <Candidate>[]
                : lookupState.candidates
                      .where((candidate) => candidate.listId == selectedListId)
                      .toList();

            filteredCandidates.sort((a, b) {
              int extractNumber(String name) {
                final match = RegExp(r'\d+').firstMatch(name);
                return match != null ? int.parse(match.group(0)!) : 999999;
              }

              int numA = extractNumber(a.candidateName);
              int numB = extractNumber(b.candidateName);
              if (numA != numB) {
                return numA.compareTo(numB);
              }
              return a.candidateName.compareTo(b.candidateName);
            });

            final selectedCandidates = filteredCandidates
                .where((c) => selectedCandidateIds.contains(c.id))
                .toList();

            final canConfirm =
                selectedListId != null && selectedCandidateIds.length <= 5;

            return AlertDialog(
              title: const Text('تأكيد التصويت'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'اختر من 0 إلى 5 مرشحين من القائمة المختارة (اختياري)',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        initialValue: selectedListId,
                        decoration: const InputDecoration(
                          labelText: 'القائمة الانتخابية',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('اختر قائمة'),
                          ),
                          ...lookupState.electoralLists.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.id,
                              child: Text(item.listName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedListId = value;
                            selectedCandidateIds.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selectedListId != null) ...[
                        Text(
                          'المرشحون المختارون: ${selectedCandidateIds.length}/5',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedCandidateIds.isNotEmpty
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...filteredCandidates.map((candidate) {
                          final isSelected = selectedCandidateIds.contains(
                            candidate.id,
                          );
                          return CheckboxListTile(
                            title: Text(candidate.candidateName),
                            value: isSelected,
                            dense: true,
                            enabled:
                                isSelected || selectedCandidateIds.length < 5,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true &&
                                    selectedCandidateIds.length < 5) {
                                  selectedCandidateIds.add(candidate.id);
                                } else {
                                  selectedCandidateIds.remove(candidate.id);
                                }
                              });
                            },
                          );
                        }),
                        if (selectedCandidateIds.isNotEmpty) ...[
                          const Divider(),
                          const Text(
                            'المرشحون المحددون:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: selectedCandidates.map((c) {
                              return Chip(
                                label: Text(c.candidateName),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setDialogState(() {
                                    selectedCandidateIds.remove(c.id);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: canConfirm
                      ? () async {
                          Navigator.pop(dialogContext);
                          await _updateStatus(
                            screenContext,
                            AppConstants.statusVoted,
                            listId: selectedListId,
                            candidateIds: selectedCandidateIds.toList(),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canConfirm
                        ? AppColors.statusVoted
                        : Colors.grey,
                  ),
                  child: Text(
                    canConfirm
                        ? 'تأكيد التصويت (${selectedCandidateIds.length})'
                        : 'اختر قائمة على الأقل، و5 مرشحين كحد أقصى',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRefusalDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض (اختياري)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateStatus(
                context,
                AppConstants.statusRefused,
                refusalReason: controller.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRefused,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
