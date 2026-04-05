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

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _applyFilters(BuildContext context, {String? status}) {
    final state = context.read<VotersCubit>().state;
    final currentStatus = status ?? (state is VotersLoaded ? state.filterStatus : null);
    
    context.read<VotersCubit>().loadVoters(
      familyIds: _selectedFamilyId != null ? [_selectedFamilyId!] : null,
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
                onChanged: (value) {
                  _debouncer.run(() {
                    context.read<VotersCubit>().searchVoters(value);
                  });
                },
              ),
              const SizedBox(height: 12),
              BlocBuilder<LookupCubit, LookupState>(
                builder: (context, lookupState) {
                  if (lookupState is! LookupLoaded) return const SizedBox.shrink();
                  
                  // Filter sub-clans based on selected family
                  final availableSubClans = _selectedFamilyId == null
                      ? lookupState.subClans
                      : lookupState.subClans
                          .where((s) => s.familyId == _selectedFamilyId)
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
                              value: _selectedFamilyId,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('الكل (العائلة)'),
                                ),
                                ...lookupState.families.map((f) => DropdownMenuItem(
                                      value: f.id,
                                      child: Text(f.familyName),
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
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: BlocBuilder<VotersCubit, VotersState>(
            builder: (context, state) {
              if (state is VotersInitial ||
                  (state is VotersLoading &&
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
