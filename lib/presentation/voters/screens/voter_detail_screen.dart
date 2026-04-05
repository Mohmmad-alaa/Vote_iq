import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
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
                        value: selectedListId,
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

