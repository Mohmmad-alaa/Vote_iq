import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class FilterChipsList extends StatelessWidget {
  final List<String> labels;
  final String? selectedLabel;
  final ValueChanged<String?> onSelected;

  const FilterChipsList({
    super.key,
    required this.labels,
    this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: labels.map((label) {
          final isSelected = label == selectedLabel;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onSelected(label);
                } else {
                  onSelected(null);
                }
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
