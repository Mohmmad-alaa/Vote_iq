import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/voter.dart';
import '../../common_widgets/excel_filter_header.dart';
import '../../lookup/cubit/lookup_cubit.dart';
import '../../lookup/cubit/lookup_state.dart';
import '../cubit/voters_cubit.dart';
import '../cubit/voters_state.dart';

/// Column definitions for the voters Excel-like table.
enum _ColumnKey { symbol, name, father, grandfather, family, status }

class _ColumnInfo {
  final _ColumnKey key;
  final String label;
  final double flex;

  const _ColumnInfo(this.key, this.label, this.flex);
}

const _columns = [
  _ColumnInfo(_ColumnKey.symbol, 'الرقم الانتخابي', 1.2),
  _ColumnInfo(_ColumnKey.name, 'الاسم', 1.3),
  _ColumnInfo(_ColumnKey.father, 'اسم الأب', 1.3),
  _ColumnInfo(_ColumnKey.grandfather, 'اسم الجد', 1.3),
  _ColumnInfo(_ColumnKey.family, 'العائلة', 1.2),
  _ColumnInfo(_ColumnKey.status, 'الحالة', 1.0),
];

class VotersDataTable extends StatefulWidget {
  final bool isAdmin;
  final void Function(Voter) onTap;
  final void Function(Voter)? onEdit;
  final void Function(Voter)? onDelete;

  const VotersDataTable({
    super.key,
    required this.isAdmin,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<VotersDataTable> createState() => _VotersDataTableState();
}

class _VotersDataTableState extends State<VotersDataTable> {
  _ColumnKey? _sortKey;
  bool _sortAsc = true;
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = AppConstants.pageSize;
  int _lastDatasetLength = -1;
  List<Voter>? _cachedDisplayed;
  List<Voter>? _cachedSource;
  _ColumnKey? _cachedSortKey;
  bool? _cachedSortAsc;
  int _cachedFiltersHash = 0;

  final Map<_ColumnKey, Set<String>> _columnFilters = {};
  final Map<_ColumnKey, GlobalKey> _filterKeys = {};

  String _normalizeLookupName(String value) => value.trim();

  Map<String, List<int>> _familyIdsByNameFromLookup() {
    final lookupState = context.read<LookupCubit>().state;
    final grouped = <String, List<int>>{};

    if (lookupState is LookupLoaded) {
      for (final family in lookupState.families) {
        final familyName = _normalizeLookupName(family.familyName);
        grouped.putIfAbsent(familyName, () => <int>[]).add(family.id);
      }
    } else {
      final votersState = context.read<VotersCubit>().state;
      if (votersState is VotersLoaded) {
        for (final voter in votersState.voters) {
          if (voter.familyId == null || voter.familyName == null) {
            continue;
          }
          final familyName = _normalizeLookupName(voter.familyName!);
          grouped.putIfAbsent(familyName, () => <int>[]).add(voter.familyId!);
        }
      }
    }

    for (final ids in grouped.values) {
      ids.sort();
    }
    return grouped;
  }

  @override
  void initState() {
    super.initState();
    for (final col in _columns) {
      _filterKeys[col.key] = GlobalKey();
    }
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;

    final state = context.read<VotersCubit>().state;
    if (state is! VotersLoaded) return;

    final totalDisplayed = _getDisplayedRows(state.voters).length;
    if (_visibleCount >= totalDisplayed) {
      if (!state.hasReachedEnd && !state.isLoadingMore) {
        context.read<VotersCubit>().loadMore();
      }
      return;
    }

    setState(() {
      _visibleCount = math.min(
        _visibleCount + AppConstants.pageSize,
        totalDisplayed,
      );
    });
  }

  String _cellText(Voter v, _ColumnKey key) {
    switch (key) {
      case _ColumnKey.symbol:
        return v.voterSymbol;
      case _ColumnKey.name:
        return v.firstName ?? '';
      case _ColumnKey.father:
        return v.fatherName ?? '';
      case _ColumnKey.grandfather:
        return v.grandfatherName ?? '';
      case _ColumnKey.family:
        return _normalizeLookupName(v.familyName ?? '');
      case _ColumnKey.status:
        return v.status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusVoted:
        return AppColors.statusVoted;
      case AppConstants.statusRefused:
        return AppColors.statusRefused;
      default:
        return AppColors.statusNotVoted;
    }
  }

  List<Voter> _applyFiltersAndSort(List<Voter> source) {
    if (_columnFilters.isEmpty && _sortKey == null) {
      return source;
    }

    Iterable<Voter> result = source;

    for (final entry in _columnFilters.entries) {
      if (entry.value.isEmpty) continue;
      final key = entry.key;
      final selected = entry.value;
      result = result.where((v) => selected.contains(_cellText(v, key)));
    }

    final list = result.toList(growable: false);

    if (_sortKey != null) {
      final key = _sortKey!;
      list.sort((a, b) {
        final cmp = _cellText(a, key).compareTo(_cellText(b, key));
        return _sortAsc ? cmp : -cmp;
      });
    }

    return list;
  }

  int _filtersHash() {
    final parts = <Object>[];
    final entries = _columnFilters.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    for (final entry in entries) {
      parts.add(entry.key.index);
      final values = entry.value.toList()..sort();
      parts.addAll(values);
    }

    return Object.hashAll(parts);
  }

  void _invalidateDisplayedCache() {
    _cachedDisplayed = null;
    _cachedSource = null;
    _cachedSortKey = null;
    _cachedSortAsc = null;
    _cachedFiltersHash = 0;
  }

  List<Voter> _getDisplayedRows(List<Voter> source) {
    final filtersHash = _filtersHash();
    if (_cachedDisplayed != null &&
        identical(_cachedSource, source) &&
        _cachedSortKey == _sortKey &&
        _cachedSortAsc == _sortAsc &&
        _cachedFiltersHash == filtersHash) {
      return _cachedDisplayed!;
    }

    final displayed = _applyFiltersAndSort(source);
    _cachedDisplayed = displayed;
    _cachedSource = source;
    _cachedSortKey = _sortKey;
    _cachedSortAsc = _sortAsc;
    _cachedFiltersHash = filtersHash;
    return displayed;
  }

  void _toggleSort(_ColumnKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
      _invalidateDisplayedCache();
      _lastDatasetLength = -1;
    });
  }

  void _openFilter(_ColumnKey key, List<Voter> allVoters) {
    if (key == _ColumnKey.family) {
      _openFamilyFilter(key);
      return;
    }

    final allValues = allVoters.map((v) => _cellText(v, key)).toList();
    showExcelFilter<String>(
      context: context,
      triggerKey: _filterKeys[key]!,
      allValues: allValues,
      selectedValues: _columnFilters[key] ?? {},
      displayText: (v) => v.isEmpty ? '(فارغ)' : v,
      onApply: (selected) {
        setState(() {
          if (selected.isEmpty || selected.length == allValues.toSet().length) {
            _columnFilters.remove(key);
          } else {
            _columnFilters[key] = selected;
          }
          _invalidateDisplayedCache();
          _lastDatasetLength = -1;
        });
      },
      onClear: () {
        setState(() {
          _columnFilters.remove(key);
          _invalidateDisplayedCache();
          _lastDatasetLength = -1;
        });
      },
    );
  }

  void _openFamilyFilter(_ColumnKey key) async {
    final cubit = context.read<VotersCubit>();
    final familyIdsByName = _familyIdsByNameFromLookup();
    final allValues = familyIdsByName.keys.toList()..sort();
    showExcelFilter<String>(
      context: context,
      triggerKey: _filterKeys[key]!,
      allValues: allValues,
      selectedValues: _columnFilters[key] ?? {},
      displayText: (v) => v.isEmpty ? '(فارغ)' : v,
      onApply: (selected) async {
        setState(() {
          if (selected.isEmpty || selected.length == allValues.toSet().length) {
            _columnFilters.remove(key);
          } else {
            _columnFilters[key] = selected;
          }
          _invalidateDisplayedCache();
          _lastDatasetLength = -1;
        });

        final currentState = cubit.state;
        String? status;
        if (currentState is VotersLoaded) {
          status = currentState.filterStatus;
        }

        if (selected.isEmpty) {
          cubit.loadVoters(status: status);
          return;
        }

        final selectedFamilyIds = <int>[];
        for (final familyName in selected) {
          final familyIds = familyIdsByName[familyName];
          if (familyIds != null) {
            selectedFamilyIds.addAll(familyIds);
          }
        }

        if (selectedFamilyIds.isNotEmpty) {
          cubit.loadVoters(
            familyIds: selectedFamilyIds.toSet().toList(),
            status: status,
          );
        } else {
          cubit.loadVoters(status: status);
        }
      },
      onClear: () {
        setState(() {
          _columnFilters.remove(key);
          _invalidateDisplayedCache();
          _lastDatasetLength = -1;
        });

        final currentState = cubit.state;
        String? status;
        if (currentState is VotersLoaded) {
          status = currentState.filterStatus;
        }
        cubit.loadVoters(status: status);
      },
    );
  }

  bool _isFiltered(_ColumnKey key) =>
      _columnFilters.containsKey(key) && _columnFilters[key]!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VotersCubit, VotersState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is VotersLoaded &&
              current is VotersLoaded &&
              (previous.voters != current.voters ||
                  previous.totalCount != current.totalCount ||
                  previous.isLoadingMore != current.isLoadingMore ||
                  previous.hasReachedEnd != current.hasReachedEnd)),
      builder: (context, state) {
        if (state is! VotersLoaded) return const SizedBox.shrink();
        if (state.voters.isEmpty) {
          return const Center(
            child: Text(
              'لا يوجد ناخبين مسجلين',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          );
        }

        final displayed = _getDisplayedRows(state.voters);
        final hasAnyFilter = _columnFilters.isNotEmpty;
        final datasetLength = displayed.length;
        if (_lastDatasetLength != datasetLength) {
          final previousLength = _lastDatasetLength;
          _lastDatasetLength = datasetLength;
          if (datasetLength == 0) {
            _visibleCount = 0;
          } else if (previousLength < 0) {
            _visibleCount = math.min(AppConstants.pageSize, datasetLength);
          } else if (datasetLength < previousLength) {
            _visibleCount = math.min(_visibleCount, datasetLength);
          } else if (datasetLength > previousLength) {
            _visibleCount = datasetLength;
          }
        }
        final visibleRows = displayed.take(_visibleCount).toList();

        return Column(
          children: [
            if (hasAnyFilter)
              Container(
                width: double.infinity,
                color: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${displayed.length} / ${state.totalCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() {
                        _columnFilters.clear();
                        _invalidateDisplayedCache();
                        _lastDatasetLength = -1;
                      }),
                      child: const Text(
                        'مسح كل الفلاتر',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.statusRefused,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: visibleRows.length,
                itemBuilder: (context, index) {
                  final voter = visibleRows[index];
                  final isEven = index.isEven;
                  return _buildRow(voter, isEven);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.scaffoldBg,
              child: Row(
                children: [
                  Text(
                    '${visibleRows.length} / ${state.totalCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (state.isLoadingMore) ...[
                    const Spacer(),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(bottom: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: Row(
        children: _columns.map((col) {
          final isSorting = _sortKey == col.key;
          final isFiltering = _isFiltered(col.key);

          return Expanded(
            flex: (col.flex * 100).toInt(),
            child: InkWell(
              onTap: () => _toggleSort(col.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFF3A6B94), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        col.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSorting)
                      Icon(
                        _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: Colors.white,
                      ),
                    InkWell(
                      key: _filterKeys[col.key],
                      onTap: () {
                        final state = context.read<VotersCubit>().state;
                        if (state is VotersLoaded) {
                          _openFilter(col.key, state.voters);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          isFiltering
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                          size: 16,
                          color: isFiltering
                              ? const Color(0xFFE8C86A)
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(Voter v, bool isEven) {
    final statusColor = _statusColor(v.status);

    return InkWell(
      onTap: () => widget.onTap(v),
      child: Container(
        decoration: BoxDecoration(
          color: isEven ? Colors.white : const Color(0xFFF8FAFC),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        child: Row(
          children: _columns.map((col) {
            final text = _cellText(v, col.key);

            Widget cell;
            if (col.key == _ColumnKey.status) {
              cell = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            } else {
              cell = Text(
                text.isEmpty ? '-' : text,
                style: TextStyle(
                  fontSize: 13,
                  color: text.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              );
            }

            return Expanded(
              flex: (col.flex * 100).toInt(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                  ),
                ),
                child: cell,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
