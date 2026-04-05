import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    IconData icon;

    switch (status) {
      case AppConstants.statusVoted:
        backgroundColor = AppColors.statusVotedBg;
        textColor = AppColors.statusVoted;
        borderColor = AppColors.statusVoted.withValues(alpha: 0.3);
        icon = Icons.check_circle_outline_rounded;
        break;
      case AppConstants.statusRefused:
        backgroundColor = AppColors.statusRefusedBg;
        textColor = AppColors.statusRefused;
        borderColor = AppColors.statusRefused.withValues(alpha: 0.3);
        icon = Icons.cancel_outlined;
        break;
      case AppConstants.statusNotVoted:
      default:
        backgroundColor = AppColors.statusNotVotedBg;
        textColor = AppColors.statusNotVoted;
        borderColor = AppColors.statusNotVoted.withValues(alpha: 0.3);
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 13),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
