import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CustomSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool isSearching;

  const CustomSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'بحث بالاسم، الأب، الجد، العائلة، الرقم...',
    this.isSearching = false,
  });

  @override
  State<CustomSearchField> createState() => _CustomSearchFieldState();
}

class _CustomSearchFieldState extends State<CustomSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: (value) {
          setState(() {}); // rebuild to show/hide clear button
          widget.onChanged(value);
        },
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: widget.isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : const Icon(Icons.search, color: AppColors.primary),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
