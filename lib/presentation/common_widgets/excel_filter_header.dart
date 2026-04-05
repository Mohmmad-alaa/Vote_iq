import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A filter dropdown popup similar to Excel's column filter.
/// Shows a search box, select-all checkbox, and scrollable list of values.
class ExcelFilterDropdown<T extends Object> extends StatefulWidget {
  final List<T> allValues;
  final Set<T> selectedValues;
  final String Function(T) displayText;
  final void Function(Set<T>) onApply;
  final VoidCallback onClear;
  final T? Function(T)? lookupValue;

  const ExcelFilterDropdown({
    super.key,
    required this.allValues,
    required this.selectedValues,
    required this.displayText,
    required this.onApply,
    required this.onClear,
    this.lookupValue,
  });

  @override
  State<ExcelFilterDropdown<T>> createState() =>
      _ExcelFilterDropdownState<T>();
}

class _ExcelFilterDropdownState<T extends Object>
    extends State<ExcelFilterDropdown<T>> {
  late final TextEditingController _searchController;
  late Set<T> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selected = {...widget.selectedValues};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uniqueValues = <T>{...widget.allValues}.toList()
      ..sort((a, b) => widget.displayText(a).compareTo(widget.displayText(b)));

    final filtered = _search.isEmpty
        ? uniqueValues
        : uniqueValues
            .where((v) => widget
                .displayText(v)
                .toLowerCase()
                .contains(_search.toLowerCase()))
            .toList();

    final allSelected =
        filtered.isNotEmpty && filtered.every((v) => _selected.contains(v));
    final someSelected =
        filtered.any((v) => _selected.contains(v)) && !allSelected;

    return Container(
      width: 250,
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),

          // Select all
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (allSelected) {
                    for (final v in filtered) {
                      _selected.remove(v);
                    }
                  } else {
                    for (final v in filtered) {
                      _selected.add(v);
                    }
                  }
                });
              },
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: allSelected ? true : (someSelected ? null : false),
                      tristate: true,
                      onChanged: (_) {
                        setState(() {
                          if (allSelected) {
                            for (final v in filtered) {
                              _selected.remove(v);
                            }
                          } else {
                            for (final v in filtered) {
                              _selected.add(v);
                            }
                          }
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('تحديد الكل',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Values list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final value = filtered[index];
                final isSelected = _selected.contains(value);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(value);
                      } else {
                        _selected.add(value);
                      }
                    });
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) {
                              setState(() {
                                if (isSelected) {
                                  _selected.remove(value);
                                } else {
                                  _selected.add(value);
                                }
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.displayText(value),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onClear();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('مسح الفلتر', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_selected);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('تطبيق',
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the Excel filter dropdown at the given position.
Future<void> showExcelFilter<T extends Object>({
  required BuildContext context,
  required GlobalKey triggerKey,
  required List<T> allValues,
  required Set<T> selectedValues,
  required String Function(T) displayText,
  required void Function(Set<T>) onApply,
  required VoidCallback onClear,
}) async {
  final renderBox =
      triggerKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  final offset = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;

  await showMenu(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height,
      offset.dx + 250,
      offset.dy,
    ),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    constraints: const BoxConstraints(minWidth: 250, maxWidth: 250),
    items: [
      PopupMenuItem(
        enabled: false,
        padding: EdgeInsets.zero,
        child: ExcelFilterDropdown<T>(
          allValues: allValues,
          selectedValues: selectedValues,
          displayText: displayText,
          onApply: onApply,
          onClear: onClear,
        ),
      ),
    ],
  );
}
