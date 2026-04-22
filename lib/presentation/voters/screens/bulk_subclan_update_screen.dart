import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/sub_clan.dart';
import '../../../domain/entities/voter.dart';
import '../../../core/di/injection_container.dart';
import '../../../domain/repositories/voter_repository.dart';
import '../../lookup/cubit/lookup_cubit.dart';
import '../../lookup/cubit/lookup_state.dart';
import '../cubit/voters_cubit.dart';
import '../cubit/voters_state.dart';
import '../../../data/datasources/remote/supabase_lookup_datasource.dart';
import '../../../data/datasources/remote/supabase_voter_datasource.dart';

class BulkSubClanUpdateScreen extends StatefulWidget {
  const BulkSubClanUpdateScreen({super.key});

  @override
  State<BulkSubClanUpdateScreen> createState() =>
      _BulkSubClanUpdateScreenState();
}

class _BulkSubClanUpdateScreenState
    extends State<BulkSubClanUpdateScreen> with SingleTickerProviderStateMixin {
  final Set<String> _selectedSymbols = {};
  final TextEditingController _familySearchController = TextEditingController();
  final TextEditingController _voterSearchController = TextEditingController();
  final VoterRepository _voterRepository = sl<VoterRepository>();

  int? _selectedFamilyId;
  int? _selectedSubClanId;
  String _familySearchQuery = '';
  String _voterSearchText = '';
  bool _familyDropdownOpen = false;
  bool _isRemoveMode = false;
  bool _subClanDropdownOpen = false;
  List<Voter> _screenVoters = const [];
  bool _isLoadingVoters = true;
  String? _votersError;
  bool _isApplying = false;

  late final AnimationController _animController;
  late final Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _headerAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
    
    // Invalidate caches to ensure global access agents see families instantly
    try {
      sl<SupabaseLookupDatasource>().invalidatePermissionsCache();
      sl<SupabaseVoterDatasource>().invalidatePermissionsCache();
    } catch (_) {}
    
    _loadScreenVoters();
  }

  @override
  void dispose() {
    _familySearchController.dispose();
    _voterSearchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadScreenVoters() async {
    setState(() {
      _isLoadingVoters = true;
      _votersError = null;
    });

    final result = await _voterRepository.getVoters(
      const VoterFilter(
        pageSize: 0,
        includeManageableUnassigned: true,
      ),
    );
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _screenVoters = const [];
        _isLoadingVoters = false;
        _votersError = failure.message;
      }),
      (voters) => setState(() {
        _screenVoters = voters;
        _isLoadingVoters = false;
        _votersError = null;
      }),
    );
  }

  void _updateSelection(String symbol, bool selected) {
    setState(() {
      if (selected) {
        _selectedSymbols.add(symbol);
      } else {
        _selectedSymbols.remove(symbol);
      }
    });
  }

  void _selectAll(bool select, List<Voter> voters) {
    setState(() {
      if (select) {
        _selectedSymbols.addAll(voters.map((v) => v.voterSymbol));
      } else {
        _selectedSymbols.clear();
      }
    });
  }

  List<Voter> _getFilteredVoters(VotersState votersState) {
    final source = _screenVoters.isNotEmpty
        ? _screenVoters
        : (votersState is VotersLoaded
            ? votersState.voters
            : const <Voter>[]);

    if (_isRemoveMode) {
      var filtered = source.where((v) => v.subClanId != null);

      // When a specific sub-clan is selected, skip family filter so we can
      // see cross-family voters who were added to this sub-clan.
      if (_selectedFamilyId != null && _selectedSubClanId == null) {
        filtered = filtered.where((v) => v.familyId == _selectedFamilyId);
      }
      if (_selectedSubClanId != null) {
        filtered = filtered.where((v) => v.subClanId == _selectedSubClanId);
      }

      return filtered
          .where((v) =>
              _voterSearchText.isEmpty ||
              v.fullName.contains(_voterSearchText))
          .toList();
    }

    return source
        .where((v) => v.subClanId == null)
        .where((v) =>
            _voterSearchText.isEmpty || v.fullName.contains(_voterSearchText))
        .toList();
  }

  Future<void> _applyUpdate(
    BuildContext context,
    LookupLoaded lookupState,
    List<Voter> voters,
  ) async {
    if (_selectedSymbols.isEmpty) {
      if (!mounted) return;
      _showSnack(context, 'يرجى تحديد ناخبين أولاً', isWarning: true);
      return;
    }

    if (!_isRemoveMode && _selectedSubClanId == null) {
      if (!mounted) return;
      _showSnack(context, 'يرجى اختيار الفرع أولاً', isWarning: true);
      return;
    }

    setState(() => _isApplying = true);

    try {
      final cubit = context.read<VotersCubit>();
      int successCount = 0;

      for (final voter in voters) {
        if (!_selectedSymbols.contains(voter.voterSymbol)) continue;

        final selectedSubClan = lookupState.subClans
            .cast<SubClan?>()
            .firstWhere((s) => s?.id == _selectedSubClanId, orElse: () => null);

        final updatedVoter = Voter(
          voterSymbol: voter.voterSymbol,
          firstName: voter.firstName,
          fatherName: voter.fatherName,
          grandfatherName: voter.grandfatherName,
          familyId: voter.familyId,
          subClanId: _isRemoveMode ? null : _selectedSubClanId,
          centerId: voter.centerId,
          status: voter.status,
          refusalReason: voter.refusalReason,
          updatedAt: voter.updatedAt,
          updatedBy: voter.updatedBy,
          familyName: voter.familyName,
          subClanName: _isRemoveMode ? null : selectedSubClan?.subName,
          centerName: voter.centerName,
        );
        await cubit.updateVoter(updatedVoter, reload: false);
        successCount++;
      }

      if (mounted) {
        if (successCount > 0) {
          cubit.refreshCurrentView(forceRefresh: false);
        }
        // ignore: use_build_context_synchronously
        _showSnack(
          // ignore: use_build_context_synchronously
          context,
          _isRemoveMode
              ? 'تم حذف $successCount ناخب من الفروع بنجاح'
              : 'تم تحديث الفرع لـ $successCount ناخب بنجاح',
          isSuccess: true,
        );
        
        // Update _screenVoters locally instead of full reload
        setState(() {
          for (int i = 0; i < _screenVoters.length; i++) {
            final v = _screenVoters[i];
            if (_selectedSymbols.contains(v.voterSymbol)) {
              if (_isRemoveMode) {
                // If removing, we create a new Voter with null subClan fields
                // We cannot use copyWith because it ignores null values
                _screenVoters[i] = Voter(
                  voterSymbol: v.voterSymbol,
                  firstName: v.firstName,
                  fatherName: v.fatherName,
                  grandfatherName: v.grandfatherName,
                  familyId: v.familyId,
                  subClanId: null,
                  centerId: v.centerId,
                  listId: v.listId,
                  candidateId: v.candidateId,
                  status: v.status,
                  refusalReason: v.refusalReason,
                  updatedAt: v.updatedAt,
                  updatedBy: v.updatedBy,
                  familyName: v.familyName,
                  subClanName: null,
                  centerName: v.centerName,
                  listName: v.listName,
                  candidateName: v.candidateName,
                );
              } else {
                // If adding, we set the new subClan but keep the old family
                final selectedSubClan = lookupState.subClans
                    .cast<SubClan?>()
                    .firstWhere((s) => s?.id == _selectedSubClanId, orElse: () => null);

                _screenVoters[i] = Voter(
                  voterSymbol: v.voterSymbol,
                  firstName: v.firstName,
                  fatherName: v.fatherName,
                  grandfatherName: v.grandfatherName,
                  familyId: v.familyId,
                  subClanId: _selectedSubClanId,
                  centerId: v.centerId,
                  listId: v.listId,
                  candidateId: v.candidateId,
                  status: v.status,
                  refusalReason: v.refusalReason,
                  updatedAt: v.updatedAt,
                  updatedBy: v.updatedBy,
                  familyName: v.familyName,
                  subClanName: selectedSubClan?.subName,
                  centerName: v.centerName,
                  listName: v.listName,
                  candidateName: v.candidateName,
                );
              }
            }
          }
          _selectedSymbols.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _showSnack(BuildContext context, String message,
      {bool isWarning = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : isWarning
                      ? Icons.warning_rounded
                      : Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: isSuccess
            ? AppColors.success
            : isWarning
                ? Colors.orange.shade700
                : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LookupCubit>()..loadAll(),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: _buildAppBar(),
        body: BlocBuilder<VotersCubit, VotersState>(
          builder: (context, votersState) {
            return BlocBuilder<LookupCubit, LookupState>(
              builder: (context, lookupState) {
                if (lookupState is! LookupLoaded || _isLoadingVoters) {
                  return const _LoadingIndicator();
                }
                if (_votersError != null) {
                  return _ErrorView(
                    message: _votersError!,
                    onRetry: _loadScreenVoters,
                  );
                }

                final filteredVoters = _getFilteredVoters(votersState);

                return CustomScrollView(
                  slivers: [
                    // ─── Control Panel ───
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _headerAnim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.1),
                            end: Offset.zero,
                          ).animate(_headerAnim),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = MediaQuery.of(context).size.width < 600;
                              return _buildControlPanel(
                                context, lookupState, votersState,
                                filteredVoters, isMobile);
                            },
                          ),
                        ),
                      ),
                    ),

                    // ─── Search + Select-All bar ───
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickySearchDelegate(
                        filterHint: _isRemoveMode
                            ? 'ابحث عن ناخب في فرع...'
                            : 'ابحث عن ناخب بدون فرع...',
                        controller: _voterSearchController,
                        onChanged: (val) =>
                            setState(() => _voterSearchText = val),
                        totalCount: filteredVoters.length,
                        selectedCount: _selectedSymbols.length,
                        allSelected: filteredVoters.isNotEmpty &&
                            _selectedSymbols.length == filteredVoters.length,
                        onSelectAll: (val) =>
                            _selectAll(val ?? false, filteredVoters),
                      ),
                    ),

                    // ─── Voter List ───
                    if (filteredVoters.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(isRemoveMode: _isRemoveMode),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final voter = filteredVoters[i];
                              final isSelected = _selectedSymbols
                                  .contains(voter.voterSymbol);
                              return _VoterCard(
                                voter: voter,
                                isSelected: isSelected,
                                isRemoveMode: _isRemoveMode,
                                onChanged: (val) => _updateSelection(
                                    voter.voterSymbol, val ?? false),
                                index: i,
                              );
                            },
                            childCount: filteredVoters.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        // ─── Floating Action Button ───
        floatingActionButton: _buildFab(context),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
      ),
      title: const Text(
        'تحديث الفروع جماعياً',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (_selectedSymbols.isNotEmpty)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_selectedSymbols.length} محدد',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlPanel(
    BuildContext context,
    LookupLoaded lookupState,
    VotersState votersState,
    List<Voter> filteredVoters,
    bool isMobile,
  ) {
    return Container(
      margin: EdgeInsets.fromLTRB(isMobile ? 8 : 12, isMobile ? 8 : 12, isMobile ? 8 : 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowBlue,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─ Mode Toggle ─
          _buildModeToggle(isMobile: isMobile),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          // ─ Dropdowns ─
          Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 16),
            child: Column(
              children: [
                _buildSearchableFamilyDropdown(lookupState),
                const SizedBox(height: 10),
                _buildSubClanDropdown(lookupState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle({bool isMobile = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: _isRemoveMode
            ? Colors.red.shade50
            : AppColors.primarySurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      child: Row(
        children: [
          Icon(
            _isRemoveMode
                ? Icons.remove_circle_rounded
                : Icons.edit_note_rounded,
            color: _isRemoveMode ? Colors.red : AppColors.primary,
            size: isMobile ? 20 : 22,
          ),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRemoveMode
                      ? 'وضع الإزالة'
                      : 'وضع الإضافة إلى فرع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14,
                    color: _isRemoveMode ? Colors.red.shade700 : AppColors.primary,
                  ),
                ),
                if (!isMobile)
                  Text(
                    _isRemoveMode
                        ? 'حدد الناخبين لإزالتهم من فروعهم'
                        : 'حدد الناخبين ثم اختر الفرع المراد الإضافة إليه',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Switch(
            value: _isRemoveMode,
            onChanged: (val) => setState(() {
              _isRemoveMode = val;
              _selectedSymbols.clear();
            }),
            activeThumbColor: Colors.red,
            inactiveThumbColor: AppColors.primary,
            inactiveTrackColor: AppColors.primarySurface,
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    if (_selectedSymbols.isEmpty) return const SizedBox.shrink();

    return BlocBuilder<VotersCubit, VotersState>(
      builder: (context, votersState) {
        return BlocBuilder<LookupCubit, LookupState>(
          builder: (context, lookupState) {
            if (lookupState is! LookupLoaded) return const SizedBox.shrink();

            final filteredVoters = _getFilteredVoters(votersState);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FloatingActionButton.extended(
                  elevation: 6,
                  backgroundColor:
                      _isRemoveMode ? Colors.red.shade700 : AppColors.primary,
                  onPressed: _isApplying
                      ? null
                      : () => _applyUpdate(context, lookupState, filteredVoters),
                  icon: _isApplying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          _isRemoveMode
                              ? Icons.remove_circle_rounded
                              : Icons.check_rounded,
                          color: Colors.white,
                        ),
                  label: Text(
                    _isApplying
                        ? 'جارٍ التطبيق...'
                        : _isRemoveMode
                            ? 'إزالة ${_selectedSymbols.length} ناخب من الفرع'
                            : 'تطبيق على ${_selectedSymbols.length} ناخب',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchableFamilyDropdown(LookupLoaded lookupState) {
    final filteredFamilies = _familySearchQuery.isEmpty
        ? lookupState.families
        : lookupState.families
            .where((f) => f.familyName
                .toLowerCase()
                .contains(_familySearchQuery.toLowerCase()))
            .toList();

    final selectedName = _selectedFamilyId != null &&
            lookupState.families.any((f) => f.id == _selectedFamilyId)
        ? lookupState.families
            .firstWhere((f) => f.id == _selectedFamilyId)
            .familyName
        : null;

    return _DropdownField(
      label: 'العائلة',
      icon: Icons.groups_3_rounded,
      selectedText: selectedName ?? 'الكل (جميع العائلات)',
      isOpen: _familyDropdownOpen,
      hasValue: _selectedFamilyId != null,
      onToggle: () => setState(() {
        _familyDropdownOpen = !_familyDropdownOpen;
        if (_familyDropdownOpen) _subClanDropdownOpen = false;
      }),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _familySearchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ابحث عن عائلة...',
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (val) =>
                  setState(() => _familySearchQuery = val),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredFamilies.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _DropdownItem(
                    title: 'الكل',
                    isSelected: _selectedFamilyId == null,
                    onTap: () => setState(() {
                      _selectedFamilyId = null;
                      _selectedSubClanId = null;
                      _familyDropdownOpen = false;
                      _familySearchQuery = '';
                      _familySearchController.clear();
                    }),
                  );
                }
                final family = filteredFamilies[i - 1];
                return _DropdownItem(
                  title: family.familyName,
                  isSelected: _selectedFamilyId == family.id,
                  onTap: () => setState(() {
                    _selectedFamilyId = family.id;
                    _selectedSubClanId = null;
                    _familyDropdownOpen = false;
                    _familySearchQuery = '';
                    _familySearchController.clear();
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubClanDropdown(LookupLoaded lookupState) {
    final subClans = _selectedFamilyId != null
        ? lookupState.subClans
            .where((s) => s.familyId == _selectedFamilyId)
            .toList()
        : List<SubClan>.from(lookupState.subClans);

    final selectedName = _selectedSubClanId != null &&
            lookupState.subClans.any((s) => s.id == _selectedSubClanId)
        ? lookupState.subClans
            .firstWhere((s) => s.id == _selectedSubClanId)
            .subName
        : null;

    return _DropdownField(
      label: 'الفرع',
      icon: Icons.account_tree_rounded,
      selectedText: selectedName ?? 'اختر الفرع',
      isOpen: _subClanDropdownOpen,
      hasValue: _selectedSubClanId != null,
      onToggle: () {
        if (subClans.isEmpty) {
          _showSnack(context,
              _selectedFamilyId == null
                  ? 'اختر عائلة أولاً لتصفية الفروع أو تفضَّل بالاختيار من الكل'
                  : 'لا توجد فروع مسجلة لهذه العائلة',
              isWarning: true);
          return;
        }
        setState(() {
          _subClanDropdownOpen = !_subClanDropdownOpen;
          if (_subClanDropdownOpen) _familyDropdownOpen = false;
        });
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: subClans.length,
          itemBuilder: (_, i) {
            final s = subClans[i];
            return _DropdownItem(
              title: s.subName,
              subtitle: _selectedFamilyId == null ? s.familyName : null,
              isSelected: _selectedSubClanId == s.id,
              onTap: () => setState(() {
                _selectedSubClanId = s.id;
                _selectedFamilyId = s.familyId;
                _subClanDropdownOpen = false;
              }),
            );
          },
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Reusable Dropdown Field Widget
/// ─────────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.icon,
    required this.selectedText,
    required this.isOpen,
    required this.hasValue,
    required this.onToggle,
    required this.child,
  });

  final String label;
  final IconData icon;
  final String selectedText;
  final bool isOpen;
  final bool hasValue;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: isOpen
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            border: Border.all(
              color: isOpen
                  ? AppColors.primary
                  : hasValue
                      ? AppColors.primaryLight
                      : AppColors.border,
              width: isOpen ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedText,
                          style: TextStyle(
                            color: hasValue
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                            fontSize: 14,
                            fontWeight: hasValue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isOpen) ...[
                const Divider(
                    height: 1, thickness: 1, color: AppColors.divider),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10)),
                  ),
                  child: child,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Reusable Dropdown Item
/// ─────────────────────────────────────────────────────
class _DropdownItem extends StatelessWidget {
  const _DropdownItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: isSelected ? AppColors.primarySurface : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded,
                  color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Sticky Search + SelectAll header
/// ─────────────────────────────────────────────────────
class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  _StickySearchDelegate({
    required this.filterHint,
    required this.controller,
    required this.onChanged,
    required this.totalCount,
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
  });

  final String filterHint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int totalCount;
  final int selectedCount;
  final bool allSelected;
  final ValueChanged<bool?> onSelectAll;

  @override
  double get minExtent => 124;

  @override
  double get maxExtent => 124;

  @override
  bool shouldRebuild(_StickySearchDelegate oldDelegate) => true;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          boxShadow: overlapsContent
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Column(
        children: [
          // Search Field
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: filterHint,
              hintStyle:
                  const TextStyle(color: AppColors.textHint, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 6),
          // Select-All bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected ? true : (selectedCount > 0 ? null : false),
                  tristate: true,
                  activeColor: AppColors.primary,
                  onChanged: onSelectAll,
                ),
                Expanded(
                  child: Text(
                    'تحديد الكل  •  $totalCount نتيجة',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (selectedCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$selectedCount محدد',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Voter Card
/// ─────────────────────────────────────────────────────
class _VoterCard extends StatelessWidget {
  const _VoterCard({
    required this.voter,
    required this.isSelected,
    required this.isRemoveMode,
    required this.onChanged,
    required this.index,
  });

  final Voter voter;
  final bool isSelected;
  final bool isRemoveMode;
  final ValueChanged<bool?> onChanged;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isRemoveMode
                ? Colors.red.shade50
                : AppColors.primarySurface)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? (isRemoveMode ? Colors.red.shade300 : AppColors.primaryLight)
              : AppColors.divider,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? (isRemoveMode
                    ? Colors.red.withValues(alpha: 0.08)
                    : AppColors.shadowBlue)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!isSelected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Checkbox area
              SizedBox(
                width: 36,
                child: Checkbox(
                  value: isSelected,
                  onChanged: onChanged,
                  activeColor: isRemoveMode ? Colors.red : AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              // Voter info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voter.fullName.isNotEmpty ? voter.fullName : 'بدون اسم',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isRemoveMode
                                ? Colors.red.shade800
                                : AppColors.primaryDark)
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (voter.familyName != null)
                          _InfoChip(
                            icon: Icons.groups_3_outlined,
                            label: voter.familyName!,
                          ),
                        if (voter.subClanName != null)
                          _InfoChip(
                            icon: Icons.account_tree_outlined,
                            label: voter.subClanName!,
                            color: Colors.teal,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Symbol
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  voter.voterSymbol,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Small info chip
/// ─────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: c),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Empty State
/// ─────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isRemoveMode});

  final bool isRemoveMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRemoveMode
                    ? Icons.check_circle_rounded
                    : Icons.people_alt_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRemoveMode
                  ? 'لا يوجد ناخبون في فروع حسب الفلتر المختار'
                  : 'جميع الناخبين منتمون لفروع',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRemoveMode
                  ? 'جرب تغيير فلتر العائلة أو الفرع للبحث عن ناخبين محددين'
                  : 'لا يوجد ناخبون بدون فرع في الوقت الحالي',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Loading Indicator
/// ─────────────────────────────────────────────────────
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'جارٍ تحميل البيانات...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────
///  Error View
/// ─────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
