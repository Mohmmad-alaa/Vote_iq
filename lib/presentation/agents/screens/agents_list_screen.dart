import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../common_widgets/error_widget.dart';
import '../../common_widgets/loading_widget.dart';
import '../cubit/agents_cubit.dart';
import '../cubit/agents_state.dart';
import 'agent_detail_screen.dart';

class AgentsListScreen extends StatefulWidget {
  const AgentsListScreen({super.key});

  @override
  State<AgentsListScreen> createState() => _AgentsListScreenState();
}

class _AgentsListScreenState extends State<AgentsListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AgentsCubit>().loadAgents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: BlocBuilder<AgentsCubit, AgentsState>(
        builder: (context, state) {
          if (state is AgentsLoading || state is AgentsInitial) {
            return const ShimmerLoader();
          }

          if (state is AgentsError) {
            return CustomErrorWidget(
              message: state.message,
              onRetry: () => context.read<AgentsCubit>().loadAgents(),
            );
          }

          if (state is AgentsLoaded) {
            if (state.agents.isEmpty) {
              return const Center(child: Text('لا يوجد وكلاء مسجلين'));
            }

            return RefreshIndicator(
              onRefresh: () => context.read<AgentsCubit>().loadAgents(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.agents.length,
                itemBuilder: (context, index) {
                  final agent = state.agents[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: agent.isActive ? AppColors.primary : Colors.grey,
                        child: Icon(
                          agent.isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        agent.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(agent.username),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: agent.isActive ? AppColors.statusVoted.withValues(alpha: 0.1) : AppColors.statusRefused.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          agent.isActive ? 'نشط' : 'موقوف',
                          style: TextStyle(
                            color: agent.isActive ? AppColors.statusVoted : AppColors.statusRefused,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<AgentsCubit>(),
                              child: AgentDetailScreen(agent: agent),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddAgentDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddAgentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isAdmin = false;
    
    final cubit = context.read<AgentsCubit>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (stateContext, setState) => AlertDialog(
            title: const Text('إضافة وكيل جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('صلاحيات مدير نظام؟'),
                    value: isAdmin,
                    onChanged: (val) => setState(() => isAdmin = val ?? false),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                    return;
                  }
                  cubit.createAgent(
                    fullName: nameCtrl.text.trim(),
                    username: userCtrl.text.trim(),
                    password: passCtrl.text,
                    isAdmin: isAdmin,
                  );
                  Navigator.pop(dialogCtx);
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}
