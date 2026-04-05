import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/voter.dart';
import 'status_badge.dart';

class VoterCard extends StatelessWidget {
  final Voter voter;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VoterCard({
    super.key,
    required this.voter,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  Color _statusColor() {
    switch (voter.status) {
      case AppConstants.statusVoted:
        return AppColors.statusVoted;
      case AppConstants.statusRefused:
        return AppColors.statusRefused;
      default:
        return AppColors.statusNotVoted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowDark,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primarySurface.withValues(alpha: 0.5),
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 5,
                height: 90,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              voter.fullName.isNotEmpty ? voter.fullName : 'بدون اسم',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadge(status: voter.status),
                          if (onEdit != null || onDelete != null) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                size: 20,
                                color: AppColors.textHint,
                              ),
                              offset: const Offset(0, 8),
                              onSelected: (value) {
                                if (value == 'edit' && onEdit != null) onEdit!();
                                if (value == 'delete' && onDelete != null) onDelete!();
                              },
                              itemBuilder: (context) => [
                                if (onEdit != null)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                      title: Text('تعديل'),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                if (onDelete != null)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                      title: Text('حذف', style: TextStyle(color: AppColors.error)),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              voter.centerName ?? 'مركز غير محدد',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.tag_rounded,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            voter.voterSymbol,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
