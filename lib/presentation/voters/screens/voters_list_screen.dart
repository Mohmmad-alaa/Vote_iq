import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../common_widgets/error_widget.dart';
import '../../common_widgets/filter_chips.dart';
import '../../common_widgets/loading_widget.dart';
import '../../common_widgets/search_field.dart';
import '../cubit/voters_cubit.dart';
import '../cubit/voters_state.dart';
import '../../lookup/cubit/lookup_cubit.dart';
import '../../lookup/cubit/lookup_state.dart';
import '../widgets/voters_data_table.dart';
import 'voter_detail_screen.dart';
import 'voter_form_screen.dart';

class VotersListScreen extends StatefulWidget {
  final bool isAdmin;
  const VotersListScreen({super.key, this.isAdmin = false});

  @override
  State<VotersListScreen> createState() => _VotersListScreenState();
}

class _VotersListScreenState extends State<VotersListScreen> {
  final _debouncer = Debouncer(milliseconds: AppConstants.searchDebounceMs);
  int? _selectedFamilyId;
  int? _selectedSubClanId;
  bool _isSearching = false;

  String _normalizeLookupName(String value) => value.trim();

  Map<String, List<int>> _groupFamilyIdsByName(LookupLoaded state) {
    final grouped = <String, List<int>>{};
    for (final family in state.families) {
      final familyName = _normalizeLookupName(family.familyName);
      grouped.putIfAbsent(familyName, () => <int>[]).add(family.id);
    }
    for (final ids in grouped.values) {
      ids.sort();
    }
    return grouped;
  }

  List<int>? _selectedFamilyIds(LookupState state) {
    if (_selectedFamilyId == null) {
      return null;
    }
    if (state is! LookupLoaded) {
      return [_selectedFamilyId!];
    }

    String? selectedFamilyName;
    for (final family in state.families) {
      if (family.id == _selectedFamilyId) {
        selectedFamilyName = _normalizeLookupName(family.familyName);
        break;
      }
    }

    if (selectedFamilyName == null) {
      return [_selectedFamilyId!];
    }

    return _groupFamilyIdsByName(state)[selectedFamilyName] ?? [_selectedFamilyId!];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final votersCubit = context.read<VotersCubit>();
      votersCubit.subscribeToRealtime();
      if (votersCubit.state is VotersInitial || votersCubit.state is VotersError) {
        votersCubit.loadVoters();
      }

      final lookupCubit = context.read<LookupCubit>();
      if (lookupCubit.state is LookupInitial || lookupCubit.state is LookupError) {
        lookupCubit.loadAll();
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _applyFilters(BuildContext context, {String? status}) {
    final state = context.read<VotersCubit>().state;
    final currentStatus = status ?? (state is VotersLoaded ? state.filterStatus : null);
    final lookupState = context.read<LookupCubit>().state;
    
    context.read<VotersCubit>().loadVoters(
      familyIds: _selectedFamilyIds(lookupState),
      subClanId: _selectedSubClanId,
      status: currentStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.getScreenPadding(context);

    return Column(
      children: [
        // Search & Filter header
        Container(
          color: AppColors.scaffoldBg,
          padding: padding,
          child: Column(
            children: [
              CustomSearchField(
                isSearching: _isSearching,
                onChanged: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isEmpty) {
                    // Clear search immediately, no spinner needed
                    _debouncer.cancel();
                    setState(() => _isSearching = false);
                    context.read<VotersCubit>().searchVoters('');
                  } else {
                    setState(() => _isSearching = true);
                    _debouncer.run(() {
                      context.read<VotersCubit>().searchVoters(trimmed).then((_) {
                        if (mounted) setState(() => _isSearching = false);
                      });
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              BlocBuilder<LookupCubit, LookupState>(
                buildWhen: (previous, current) =>
                    previous.runtimeType != current.runtimeType ||
                    (previous is LookupLoaded &&
                        current is LookupLoaded &&
                        (previous.families != current.families ||
                            previous.subClans != current.subClans)),
                builder: (context, lookupState) {
                  if (lookupState is! LookupLoaded) return const SizedBox.shrink();
                  
                  final familyOptions = _groupFamilyIdsByName(lookupState).entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key));
                  final selectedFamilyIds = _selectedFamilyIds(lookupState);
                  int? selectedFamilyValue;
                  if (_selectedFamilyId != null) {
                    for (final entry in familyOptions) {
                      if (entry.value.contains(_selectedFamilyId)) {
                        selectedFamilyValue = entry.value.first;
                        break;
                      }
                    }
                  }

                  // Filter sub-clans based on selected family
                  final availableSubClans = selectedFamilyIds == null
                      ? lookupState.subClans
                      : lookupState.subClans
                          .where((s) => selectedFamilyIds.contains(s.familyId))
                          .toList();

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              hint: const Text('العائلة'),
                              value: selectedFamilyValue,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('الكل (العائلة)'),
                                ),
                                ...familyOptions.map((entry) => DropdownMenuItem(
                                      value: entry.value.first,
                                      child: Text(entry.key),
                                    )),
                              ],
                              onChanged: (val) {
                                  setState(() {
                                    _selectedFamilyId = val;
                                    _selectedSubClanId = null; // reset sub-clan when family changes
                                  });
                                  _applyFilters(context);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              hint: const Text('الفرع'),
                              value: _selectedSubClanId,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('الكل (الفرع)'),
                                ),
                                ...availableSubClans.map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.subName),
                                    )),
                              ],
                              onChanged: (val) {
                                  setState(() {
                                    _selectedSubClanId = val;
                                  });
                                  _applyFilters(context);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              BlocBuilder<VotersCubit, VotersState>(
                buildWhen: (previous, current) =>
                    previous.runtimeType != current.runtimeType ||
                    (previous is VotersLoaded &&
                        current is VotersLoaded &&
                        previous.filterStatus != current.filterStatus),
                builder: (context, state) {
                  String? selectedStatus;
                  if (state is VotersLoaded) {
                    selectedStatus = state.filterStatus;
                  }

                  return FilterChipsList(
                    labels: const [
                      'الكل',
                      AppConstants.statusVoted,
                      AppConstants.statusNotVoted,
                      AppConstants.statusRefused,
                    ],
                    selectedLabel: selectedStatus ?? 'الكل',
                    onSelected: (label) {
                      final status = label == 'الكل' ? null : label;
                      _applyFilters(context, status: status);
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              BlocBuilder<VotersCubit, VotersState>(
                buildWhen: (previous, current) =>
                    previous.runtimeType != current.runtimeType ||
                    (previous is VotersLoaded &&
                        current is VotersLoaded &&
                        (previous.voters != current.voters ||
                            previous.totalCount != current.totalCount)),
                builder: (context, state) {
                  if (state is! VotersLoaded) {
                    return const SizedBox.shrink();
                  }

                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${state.voters.length} / ${state.totalCount}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: BlocBuilder<VotersCubit, VotersState>(
            buildWhen: (previous, current) =>
                previous.runtimeType != current.runtimeType ||
                (previous is VotersLoaded &&
                    current is VotersLoaded &&
                    (previous.voters != current.voters ||
                        previous.isLoadingMore != current.isLoadingMore ||
                        previous.hasReachedEnd != current.hasReachedEnd)),
            builder: (context, state) {
              // Only show shimmer on initial load, never during search
              if (state is VotersInitial ||
                  (state is VotersLoading && !_isSearching &&
                      context.read<VotersCubit>().state is! VotersLoaded)) {
                return const ShimmerLoader();
              }

              if (state is VotersError) {
                return CustomErrorWidget(
                  message: state.message,
                  onRetry: () => _applyFilters(context),
                );
              }

              return VotersDataTable(
                isAdmin: widget.isAdmin,
                onTap: (voter) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(
                            value: context.read<VotersCubit>(),
                          ),
                          BlocProvider.value(
                            value: context.read<LookupCubit>(),
                          ),
                        ],
                        child: VoterDetailScreen(voter: voter),
                      ),
                    ),
                  );
                },
                onEdit: widget.isAdmin
                    ? (voter) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<VotersCubit>(),
                              child: VoterFormScreen(voter: voter),
                            ),
                          ),
                        );
                      }
                    : null,
                onDelete: widget.isAdmin
                    ? (voter) => _showDeleteConfirm(context, voter)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirm(BuildContext context, dynamic voter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الناخب'),
        content: Text('هل أنت متأكد من حذف ${voter.fullName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<VotersCubit>().deleteVoter(voter.voterSymbol);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
