import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../domain/repositories/voter_repository.dart';
import '../../common_widgets/error_widget.dart';
import '../../common_widgets/excel_filter_header.dart';
import '../../common_widgets/loading_widget.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey _familyFilterKey = GlobalKey();
  final GlobalKey _subClanFilterKey = GlobalKey();
  final Set<String> _selectedFamilies = {};
  final Set<String> _selectedSubClans = {};
  bool _showAllFamilies = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<DashboardCubit>();
      if (cubit.state is DashboardInitial || cubit.state is DashboardError) {
        cubit.loadStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardInitial || state is DashboardLoading) {
          return const CustomLoadingWidget();
        }

        if (state is DashboardError) {
          return CustomErrorWidget(
            message: state.message,
            onRetry: () => context.read<DashboardCubit>().loadStats(),
          );
        }

        if (state is! DashboardLoaded) {
          return const SizedBox.shrink();
        }

        final overall = state.overallStats;

        return RefreshIndicator(
          onRefresh: () => context.read<DashboardCubit>().refreshStats(),
          color: AppColors.primary,
          backgroundColor: AppColors.cardBg,
          child: SingleChildScrollView(
            padding: ResponsiveHelper.getScreenPadding(context),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  icon: Icons.bar_chart_rounded,
                  title: 'الإحصائيات العامة',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                _buildOverallStatsGrid(overall.total, overall.voted,
                    overall.votedPercentage, overall.notVoted, overall.refused, overall.notFound),
                const SizedBox(height: 32),
                if (overall.total > 0) ...[
                  _buildSectionHeader(
                    icon: Icons.pie_chart_rounded,
                    title: 'نسبة المشاركة',
                    color: AppColors.statusVoted,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: [
                          PieChartSectionData(
                            color: AppColors.statusVoted,
                            value: overall.voted.toDouble(),
                            title:
                                '${overall.votedPercentage.toStringAsFixed(1)}%',
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: AppColors.statusNotVoted,
                            value: overall.notVoted.toDouble(),
                            title: '',
                            radius: 50,
                          ),
                          PieChartSectionData(
                            color: AppColors.statusRefused,
                            value: overall.refused.toDouble(),
                            title: '',
                            radius: 50,
                          ),
                          PieChartSectionData(
                            color: AppColors.statusNotFound,
                            value: overall.notFound.toDouble(),
                            title: '',
                            radius: 50,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                        AppColors.statusVoted,
                        AppConstants.statusVoted,
                      ),
                      const SizedBox(width: 16),
                      _buildLegendItem(
                        AppColors.statusNotVoted,
                        AppConstants.statusNotVoted,
                      ),
                      const SizedBox(width: 16),
                      _buildLegendItem(
                        AppColors.statusRefused,
                        AppConstants.statusRefused,
                      ),
                      const SizedBox(width: 16),
                      _buildLegendItem(
                        AppColors.statusNotFound,
                        AppConstants.statusNotFound,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                _buildSectionHeader(
                  icon: Icons.groups_3_rounded,
                  title: 'إحصائيات حسب العائلة',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 12),
                _buildFamilySection(state),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  icon: Icons.account_tree_outlined,
                  title: 'إحصائيات حسب الفرع',
                  color: Colors.teal,
                ),
                const SizedBox(height: 12),
                _buildSubClanSection(state),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  icon: Icons.list_alt_rounded,
                  title: 'إحصائيات القوائم والمرشحين',
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
                _buildListSection(state),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFamilySection(DashboardLoaded state) {
    if (!state.hasLoadedFamilyStats) {
      return _buildDeferredStatsCard(
        title: 'عرض إحصائيات العائلات',
        description:
            'لن يتم تحميل هذا القسم إلا عند الطلب لتسريع فتح صفحة المتابعة.',
        color: AppColors.accent,
        icon: Icons.groups_3_rounded,
        onPressed: () => context.read<DashboardCubit>().loadFamilyStats(),
      );
    }

    if (state.isLoadingFamilyStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final statsByFamily = state.statsByFamily ?? const <String, VoterStats>{};
    if (statsByFamily.isEmpty) {
      return _buildEmptyDeferredSection(
        message: 'لا توجد إحصائيات عائلات متاحة حاليًا.',
      );
    }

    final filteredFamilies = _getFilteredFamilies(statsByFamily);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              key: _familyFilterKey,
              decoration: BoxDecoration(
                color: (_selectedFamilies.isEmpty && !_showAllFamilies)
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : Colors.white,
                border: Border.all(
                  color: (_selectedFamilies.isEmpty && !_showAllFamilies)
                      ? AppColors.accent
                      : AppColors.divider,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showExcelFilter<String>(
                    context: context,
                    triggerKey: _familyFilterKey,
                    allValues: statsByFamily.keys.toList(),
                    selectedValues: _selectedFamilies,
                    displayText: (v) => v,
                    onApply: (selected) {
                      setState(() {
                        _showAllFamilies = false;
                        _selectedFamilies
                          ..clear()
                          ..addAll(selected);
                      });
                    },
                    onClear: () {
                      setState(() {
                        _showAllFamilies = false;
                        _selectedFamilies.clear();
                      });
                    },
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 18,
                          color:
                              (_selectedFamilies.isEmpty && !_showAllFamilies)
                              ? AppColors.accent
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showAllFamilies
                              ? 'عرض الكل'
                              : _selectedFamilies.isEmpty
                              ? 'اختر العائلات'
                              : '${_selectedFamilies.length} محدد',
                          style: TextStyle(
                            color:
                                (_selectedFamilies.isEmpty && !_showAllFamilies)
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color:
                              (_selectedFamilies.isEmpty && !_showAllFamilies)
                              ? AppColors.accent
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _showAllFamilies = !_showAllFamilies;
                  if (_showAllFamilies) {
                    _selectedFamilies.clear();
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(
                  color: _showAllFamilies
                      ? AppColors.accent
                      : AppColors.divider,
                ),
              ),
              child: Text(_showAllFamilies ? 'إخفاء الكل' : 'عرض الكل'),
            ),
            const SizedBox(width: 12),
            if (_selectedFamilies.isNotEmpty || _showAllFamilies)
              Text(
                '(${filteredFamilies.length} عائلة)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredFamilies.isEmpty)
          _buildEmptyDeferredSection(
            message:
                'اختر العائلات المطلوبة فقط، أو استخدم "عرض الكل" عند الحاجة.',
          )
        else
          ...filteredFamilies.map(
            (entry) => _buildFamilyCard(entry.key, entry.value),
          ),
      ],
    );
  }

  Widget _buildSubClanSection(DashboardLoaded state) {
    if (!state.hasLoadedSubClanStats) {
      return _buildDeferredStatsCard(
        title: 'عرض إحصائيات الفروع',
        description:
            'يتم تحميل هذا القسم عند الطلب فقط لتقليل وقت فتح صفحة المتابعة.',
        color: Colors.teal,
        icon: Icons.account_tree_outlined,
        onPressed: () => context.read<DashboardCubit>().loadSubClanStats(),
      );
    }

    if (state.isLoadingSubClanStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final statsBySubClan = state.statsBySubClan ?? const <String, VoterStats>{};
    if (statsBySubClan.isEmpty) {
      return _buildEmptyDeferredSection(
        message: 'لا توجد إحصائيات فروع متاحة حاليًا.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              key: _subClanFilterKey,
              decoration: BoxDecoration(
                color: _selectedSubClans.isEmpty
                    ? Colors.teal.withValues(alpha: 0.1)
                    : Colors.white,
                border: Border.all(
                  color: _selectedSubClans.isEmpty
                      ? Colors.teal
                      : AppColors.divider,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showExcelFilter<String>(
                    context: context,
                    triggerKey: _subClanFilterKey,
                    allValues: statsBySubClan.keys.toList(),
                    selectedValues: _selectedSubClans,
                    displayText: (v) => v,
                    onApply: (selected) {
                      setState(() {
                        _selectedSubClans
                          ..clear()
                          ..addAll(selected);
                      });
                    },
                    onClear: () {
                      setState(() => _selectedSubClans.clear());
                    },
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 18,
                          color: _selectedSubClans.isEmpty
                              ? Colors.teal
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedSubClans.isEmpty
                              ? 'الكل'
                              : '${_selectedSubClans.length} محدد',
                          style: TextStyle(
                            color: _selectedSubClans.isEmpty
                                ? Colors.teal
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: _selectedSubClans.isEmpty
                              ? Colors.teal
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedSubClans.isNotEmpty)
              Text(
                '(${_getFilteredSubClans(statsBySubClan).length} فرع)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ..._getFilteredSubClans(
          statsBySubClan,
        ).map((entry) => _buildSubClanCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildDeferredStatsCard({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: const Text('تحميل'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDeferredSection({required String message}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  List<MapEntry<String, VoterStats>> _getFilteredFamilies(
    Map<String, VoterStats> statsByFamily,
  ) {
    if (_showAllFamilies) {
      return statsByFamily.entries.toList();
    }
    if (_selectedFamilies.isEmpty) {
      return const [];
    }
    return statsByFamily.entries
        .where((entry) => _selectedFamilies.contains(entry.key))
        .toList();
  }

  List<MapEntry<String, VoterStats>> _getFilteredSubClans(
    Map<String, VoterStats> statsBySubClan,
  ) {
    if (_selectedSubClans.isEmpty) {
      return statsBySubClan.entries.toList();
    }
    return statsBySubClan.entries
        .where((entry) => _selectedSubClans.contains(entry.key))
        .toList();
  }

  Widget _buildFamilyCard(String name, VoterStats stats) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_3_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الإجمالي: ${stats.total}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'تم التصويت: ${stats.voted}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.statusVoted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.total > 0 ? stats.voted / stats.total : 0,
                      backgroundColor: AppColors.divider.withValues(alpha: 0.5),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.statusVoted,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${stats.votedPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(DashboardLoaded state) {
    if (!state.hasLoadedListStats) {
      return _buildDeferredStatsCard(
        title: 'عرض إحصائيات القوائم والمرشحين',
        description:
            'يعتمد هذا القسم على الاتصال بالإنترنت لحساب أصوات المرشحين بدقة. اضغط للتحميل.',
        color: Colors.purple,
        icon: Icons.list_alt_rounded,
        onPressed: () => context.read<DashboardCubit>().loadListStats(),
      );
    }

    if (state.isLoadingListStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final statsByList = state.statsByList ?? [];
    if (statsByList.isEmpty) {
      return _buildEmptyDeferredSection(
        message: 'لا توجد إحصائيات قوائم مرشحين متاحة حاليًا.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            'ملاحظة: يتطلب عرض أرقام دقيقة للمرشحين اتصالاً بالإنترنت.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        ...statsByList.map((listStat) => _buildListStatsCard(listStat)),
      ],
    );
  }

  Widget _buildListStatsCard(ListStatItem listStat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.how_to_vote_rounded, color: Colors.purple),
        ),
        title: Text(
          listStat.listName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'إجمالي أصوات القائمة: ${listStat.totalVotes}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: listStat.candidates.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'لا توجد أصوات لمرشحي هذه القائمة حتى الآن.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : Column(
                    children: listStat.candidates.map((candidate) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                candidate.candidateName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${candidate.votes} صوت',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubClanCard(String name, VoterStats stats) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_tree_outlined,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الإجمالي: ${stats.total}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'تم التصويت: ${stats.voted}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.statusVoted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.total > 0 ? stats.voted / stats.total : 0,
                      backgroundColor: AppColors.divider.withValues(alpha: 0.5),
                      valueColor: const AlwaysStoppedAnimation(Colors.teal),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${stats.votedPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatsGrid(
    int total,
    int voted,
    double votedPct,
    int notVoted,
    int refused,
    int notFound,
  ) {
    final items = [
      _StatItem(label: 'إجمالي الناخبين', value: total,
          icon: Icons.people_alt_rounded, color: AppColors.primary),
      _StatItem(label: 'تم التصويت', value: voted,
          icon: Icons.check_circle_rounded, color: AppColors.statusVoted,
          badge: '${votedPct.toStringAsFixed(1)}%'),
      _StatItem(label: 'لم يُصوّت', value: notVoted,
          icon: Icons.pending_actions_rounded, color: AppColors.statusNotVoted),
      _StatItem(label: 'رفض التصويت', value: refused,
          icon: Icons.cancel_rounded, color: AppColors.statusRefused),
      _StatItem(label: 'غير موجود', value: notFound,
          icon: Icons.person_off_outlined, color: AppColors.statusNotFound),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _CompactStatCard(item: items[0])),
            const SizedBox(width: 12),
            Expanded(child: _CompactStatCard(item: items[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _CompactStatCard(item: items[2])),
            const SizedBox(width: 12),
            Expanded(child: _CompactStatCard(item: items[3])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _CompactStatCard(item: items[4])),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

/// ── Data class for a single stat item ──────────────────────────────────────
class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String? badge;
}

/// ── Compact horizontal stat card ────────────────────────────────────────────
class _CompactStatCard extends StatelessWidget {
  const _CompactStatCard({required this.item});
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.color.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icon bubble ──────────────────────
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 12),
          // ── Text ────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    item.value.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ── Badge (percentage) ───────────────
          if (item.badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.badge!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
