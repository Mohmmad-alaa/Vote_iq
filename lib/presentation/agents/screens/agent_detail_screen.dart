import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection_container.dart';
import '../../../domain/entities/agent.dart';
import '../../../domain/entities/agent_permission.dart';
import '../../../domain/entities/family.dart';
import '../../../domain/entities/sub_clan.dart';
import '../../../domain/repositories/lookup_repository.dart';
import '../cubit/agents_cubit.dart';
import '../cubit/agents_state.dart';

class AgentDetailScreen extends StatefulWidget {
  final Agent agent;

  const AgentDetailScreen({super.key, required this.agent});

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint(
      '[AgentDetailScreen] open details: '
      'agentId=${widget.agent.id}, '
      'username=${widget.agent.username}, '
      'fullName=${widget.agent.fullName}',
    );
    context.read<AgentsCubit>().loadPermissions(widget.agent.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الوكيل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteAgentDialog(context, widget.agent.id),
            tooltip: 'حذف الوكيل',
          ),
        ],
      ),
      body: BlocConsumer<AgentsCubit, AgentsState>(
        listener: (context, state) {
          if (state is! AgentsLoaded) return;

          if (state.actionError != null && state.actionError!.isNotEmpty) {
            debugPrint(
              '[AgentDetailScreen] actionError: ${state.actionError}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state.actionMessage != null &&
              state.actionMessage!.isNotEmpty) {
            debugPrint(
              '[AgentDetailScreen] actionMessage: ${state.actionMessage}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionMessage!),
                backgroundColor: AppColors.success,
              ),
            );
            if (state.actionMessage == 'تم حذف الوكيل بنجاح') {
              Navigator.pop(context);
            }
          }
        },
        builder: (context, state) {
          if (state is AgentsInitial || state is AgentsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AgentsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.message,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (state is! AgentsLoaded) {
            return const SizedBox.shrink();
          }

          final currentAgent = state.agents.firstWhere(
            (agent) => agent.id == widget.agent.id,
            orElse: () => widget.agent,
          );
          final permissions = state.agentPermissions[currentAgent.id] ?? const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentAgent.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${currentAgent.username}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text(
                            'حالة الحساب',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            currentAgent.isActive
                                ? 'مفعّل ويمكنه الدخول'
                                : 'موقوف ولن يتمكن من الدخول',
                          ),
                          value: currentAgent.isActive,
                          activeThumbColor: AppColors.statusVoted,
                          onChanged: (value) {
                            context.read<AgentsCubit>().updateAgentStatus(
                              currentAgent.id,
                              value,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'نطاق الصلاحيات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.isSavingPermission)
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      TextButton.icon(
                        onPressed: () =>
                            _showAddPermissionDialog(context, currentAgent.id),
                        icon: const Icon(Icons.add_moderator),
                        label: const Text('إضافة صلاحية'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (permissions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'لا توجد صلاحيات حالية لهذا الوكيل.',
                        ),
                      ),
                    ),
                  )
                else
                  ...permissions.map((permission) {
                    final scope = _formatPermissionScope(permission);
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.verified_user,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          scope,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppColors.error,
                          ),
                          onPressed: state.isSavingPermission
                              ? null
                              : () {
                                  context.read<AgentsCubit>().removePermission(
                                    currentAgent.id,
                                    permission.id,
                                  );
                                },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteAgentDialog(BuildContext context, String agentId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف الوكيل', style: TextStyle(color: Colors.red)),
        content: const Text(
            'هل أنت متأكد من رغبتك في حذف هذا الوكيل نهائياً؟\nسيؤدي هذا إلى حذفه وعدم قدرته على الدخول مرة أخرى.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<AgentsCubit>().deleteAgent(agentId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('نعم، احذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatPermissionScope(AgentPermission permission) {
    final String managerSuffix = permission.isManager ? ' (مسؤول)' : '';
    if (permission.isGlobalAccess) {
      return 'وصول شامل$managerSuffix';
    }

    final familyLabel = permission.familyName ?? '#${permission.familyId}';
    if (permission.isFamilyLevel) {
      return 'عائلة: $familyLabel$managerSuffix';
    }

    final subClanLabel = permission.subClanName ?? '#${permission.subClanId}';
    return 'عائلة: $familyLabel - فرع: $subClanLabel$managerSuffix';
  }

  Future<void> _showAddPermissionDialog(
    BuildContext context,
    String agentId,
  ) async {
    final agentsCubit = context.read<AgentsCubit>();
    final authState = context.read<AuthCubit>().state;
    final isCurrentUserAdmin = authState is AuthAuthenticated && authState.agent.isAdmin;
    
    debugPrint(
      '[AgentDetailScreen] open add-permission dialog: agentId=$agentId, isAdmin=$isCurrentUserAdmin',
    );
    final lookupRepository = sl<LookupRepository>();
    final familiesResult = await lookupRepository.getFamilies();

    if (!mounted) return;

    List<Family> families = const [];
    familiesResult.fold((_) {}, (value) => families = value);

    String scope = 'family';
    int? selectedFamilyId;
    int? selectedSubClanId;
    String familySearchQuery = '';
    List<SubClan> subClans = const [];
    bool isLoadingSubClans = false;
    bool isSubmitting = false;
    bool isManager = false;

    Future<void> loadSubClans(StateSetter setState, int familyId) async {
      setState(() {
        isLoadingSubClans = true;
        selectedSubClanId = null;
      });

      final subClansResult = await lookupRepository.getSubClans(
        familyId: familyId,
      );
      if (!mounted) return;

      subClansResult.fold(
        (_) {
          setState(() {
            subClans = const [];
            isLoadingSubClans = false;
          });
        },
        (value) {
          setState(() {
            subClans = value;
            isLoadingSubClans = false;
          });
        },
      );
    }

    List<Family> filterFamilies() {
      final query = familySearchQuery.trim().toLowerCase();
      if (query.isEmpty) return families;

      return families
          .where((family) => family.familyName.toLowerCase().contains(query))
          .toList(growable: false);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final filteredFamilies = filterFamilies();
          final selectedFamilyStillVisible =
              selectedFamilyId == null ||
              filteredFamilies.any((family) => family.id == selectedFamilyId);

          return AlertDialog(
            title: const Text('إضافة صلاحية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'نوع الصلاحية'),
                  items: [
                    const DropdownMenuItem(
                      value: 'family',
                      child: Text('عائلة كاملة'),
                    ),
                    const DropdownMenuItem(
                      value: 'subclan',
                      child: Text('فرع محدد'),
                    ),
                    if (isCurrentUserAdmin)
                      const DropdownMenuItem(
                        value: 'global',
                        child: Text('وصول شامل (جميع العائلات والفروع)'),
                      ),
                  ],
                  onChanged: isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            scope = value ?? 'family';
                            selectedFamilyId = null;
                            selectedSubClanId = null;
                            familySearchQuery = '';
                            subClans = const [];
                          });
                        },
                ),
                if (scope == 'family') ...[
                  const SizedBox(height: 12),
                  TextField(
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'البحث عن العائلة',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        familySearchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedFamilyStillVisible ? selectedFamilyId : null,
                    decoration: const InputDecoration(labelText: 'العائلة'),
                    items: filteredFamilies
                        .map(
                          (family) => DropdownMenuItem(
                            value: family.id,
                            child: Text(family.familyName),
                          ),
                        )
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (value) async {
                            if (value == null) return;
                            setState(() {
                              selectedFamilyId = value;
                            });
                          },
                  ),
                  if (filteredFamilies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'لا توجد عائلة مطابقة للبحث',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
                if (scope == 'subclan') ...[
                  const SizedBox(height: 12),
                  DropdownSearch<SubClan>(
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'ابحث عن فرع...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    items: (String filter, _) async {
                      final result = await lookupRepository.getSubClans();
                      return result.fold(
                        (_) => [],
                        (subClans) {
                          if (filter.isEmpty) return subClans;
                          return subClans.where((s) =>
                              s.subName.toLowerCase().contains(filter.toLowerCase()) ||
                              (s.familyName?.toLowerCase().contains(filter.toLowerCase()) ?? false)
                          ).toList();
                        },
                      );
                    },
                    itemAsString: (SubClan s) => '${s.subName} (${s.familyName ?? "بدون عائلة"})',
                    compareFn: (item, selectedItem) => item.id == selectedItem.id,
                    dropdownBuilder: (context, selectedItem) {
                      return InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'الفرع',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(selectedItem != null 
                            ? '${selectedItem.subName} (${selectedItem.familyName ?? "بدون عائلة"})'
                            : 'اختر الفرع...'),
                      );
                    },
                    onChanged: isSubmitting
                        ? null
                        : (SubClan? value) {
                            setState(() {
                              selectedSubClanId = value?.id;
                              selectedFamilyId = value?.familyId;
                            });
                          },
                  ),
                ],
                if (isCurrentUserAdmin) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('صلاحيات مسؤول (إدارة)'),
                      subtitle: const Text('يمكنه التحديث الجماعي للفروع في هذا النطاق'),
                      value: isManager,
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              setState(() {
                                isManager = val;
                              });
                            },
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (scope == 'family' && selectedFamilyId == null) {
                        return;
                      }
                      if (scope == 'subclan' &&
                          (selectedFamilyId == null ||
                              selectedSubClanId == null)) {
                        return;
                      }

                      setState(() {
                        isSubmitting = true;
                      });

                      debugPrint(
                        '[AgentDetailScreen] submit permission: '
                        'agentId=$agentId, '
                        'scope=$scope, '
                        'familyId=$selectedFamilyId, '
                        'subClanId=${scope == 'subclan' ? selectedSubClanId : null}',
                      );

                      await agentsCubit.addPermission(
                        agentId: agentId,
                        familyId: scope == 'global' ? null : selectedFamilyId,
                        subClanId: scope == 'subclan' ? selectedSubClanId : null,
                        isManager: isManager,
                      );

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                    },
              child: isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        );
        },
      ),
    );
  }
}

