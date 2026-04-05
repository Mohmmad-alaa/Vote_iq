import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/datasources/remote/supabase_agent_datasource.dart';
import '../../../data/datasources/remote/supabase_lookup_datasource.dart';
import '../../../data/datasources/remote/supabase_voter_datasource.dart';
import '../../../data/sync/sync_manager.dart';
import '../../../domain/entities/agent.dart';
import '../agents/cubit/agents_cubit.dart';
import '../agents/screens/agents_list_screen.dart';
import '../auth/cubit/auth_cubit.dart';
import '../dashboard/cubit/dashboard_cubit.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../sync/cubit/sync_cubit.dart';
import '../sync/cubit/sync_state.dart';
import '../voters/cubit/voters_cubit.dart';
import '../voters/screens/voters_list_screen.dart';
import '../lookup/screens/lookup_management_screen.dart';
import '../voters/screens/voter_import_screen.dart';
import '../voters/screens/voter_form_screen.dart';
import '../voters/screens/bulk_subclan_update_screen.dart';

/// Home screen — the main shell with bottom navigation.
/// Shows different tabs based on user role (admin vs agent).
class HomeScreen extends StatefulWidget {
  final Agent agent;

  const HomeScreen({super.key, required this.agent});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackgroundAt;
  DateTime? _lastAutoRefreshAt;
  bool _wasBackgrounded = false;
  static const Duration _autoRefreshThrottle = Duration(seconds: 6);
  static const Duration _hardRefreshAfterBackground = Duration(seconds: 20);
  StreamSubscription<void>? _permissionChangesSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _permissionChangesSubscription = sl<SupabaseAgentDatasource>()
        .currentUserPermissionChanges
        .listen((_) => _handlePermissionChange());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _permissionChangesSubscription?.cancel();
    sl<SupabaseAgentDatasource>().disposeCurrentUserPermissionRealtime();
    super.dispose();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _HomeLifecycleObserver(
        onResume: _handleAppResume,
        onPause: () {
          _wasBackgrounded = true;
          _lastBackgroundAt = DateTime.now();
        },
      );

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.agent.isAdmin;
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isDesktop) {
      return _buildDesktopLayout(isAdmin);
    }
    return _buildMobileLayout(isAdmin);
  }

  Widget _buildDesktopLayout(bool isAdmin) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar Navigation Rail ──
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cardBg,
              border: Border(
                left: BorderSide(color: AppColors.divider, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowDark,
                  blurRadius: 8,
                  offset: Offset(-2, 0),
                ),
              ],
            ),
            child: NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _handleTabSelection,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.transparent,
              minWidth: 80,
              selectedIconTheme: const IconThemeData(
                color: AppColors.primary,
                size: 26,
              ),
              unselectedIconTheme: const IconThemeData(
                color: AppColors.textHint,
                size: 22,
              ),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
              ),
              indicatorColor: AppColors.primarySurface,
              destinations: isAdmin
                  ? const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard_rounded),
                        label: Text('المتابعة'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.people_outline_rounded),
                        selectedIcon: Icon(Icons.people_rounded),
                        label: Text('الناخبون'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.shield_outlined),
                        selectedIcon: Icon(Icons.shield_rounded),
                        label: Text('الوكلاء'),
                      ),
                    ]
                  : const [
                      NavigationRailDestination(
                        icon: Icon(Icons.people_outline_rounded),
                        selectedIcon: Icon(Icons.people_rounded),
                        label: Text('الناخبون'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard_rounded),
                        label: Text('المتابعة'),
                      ),
                    ],
            ),
          ),
          // ── Main Content ──
          Expanded(
            child: Column(
              children: [
                _buildAppBar(isAdmin),
                Expanded(child: _buildBody(isAdmin)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(isAdmin),
    );
  }

  Widget _buildMobileLayout(bool isAdmin) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.how_to_vote_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(_getTitle(isAdmin)),
          ],
        ),
        actions: _buildActions(isAdmin),
      ),
      body: _buildBody(isAdmin),
      bottomNavigationBar: _buildBottomNav(isAdmin),
      floatingActionButton: _buildFAB(isAdmin),
    );
  }

  Widget _buildAppBar(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        gradient: AppColors.appBarGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowBlue,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.how_to_vote_rounded, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Text(
            _getTitle(isAdmin),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: _buildActions(isAdmin)),
        ],
      ),
    );
  }

  List<Widget> _buildActions(bool isAdmin) {
    return [
      BlocBuilder<SyncCubit, SyncState>(
        builder: (context, state) {
          if (state is SyncIdle) {
            return _buildSyncIndicator(state);
          }
          return const SizedBox.shrink();
        },
      ),
      if (isAdmin)
        IconButton(
          icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white),
          tooltip: 'أدوات الإدارة',
          onPressed: () => _showManagementMenu(context),
        ),
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        tooltip: 'تسجيل الخروج',
        onPressed: () => _showLogoutDialog(context),
      ),
    ];
  }

  Widget? _buildFAB(bool isAdmin) {
    if (!isAdmin) return null;

    // Show FAB only on Voters tab (index 1)
    if (_currentIndex == 1) {
      return FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<VotersCubit>(),
              child: const VoterFormScreen(),
            ),
          ),
        ),
        tooltip: 'إضافة ناخب',
        child: const Icon(Icons.person_add_alt_1_rounded),
      );
    }
    return null;
  }

  void _showManagementMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.category_rounded, color: Colors.blue),
              title: const Text(
                'إدارة البيانات المرجعية (العائلات، المراكز...)',
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LookupManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.file_upload_rounded,
                color: Colors.green,
              ),
              title: const Text('استيراد ناخبين من Excel'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<VotersCubit>(),
                      child: const VoterImportScreen(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_add_rounded,
                color: Colors.orange,
              ),
              title: const Text('إضافة ناخب جديد يدوياً'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<VotersCubit>(),
                      child: const VoterFormScreen(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.account_tree_outlined,
                color: Colors.purple,
              ),
              title: const Text('تحديث الفروع جماعياً'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<VotersCubit>(),
                      child: const BulkSubClanUpdateScreen(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle(bool isAdmin) {
    if (isAdmin) {
      switch (_currentIndex) {
        case 0:
          return 'لوحة المتابعة';
        case 1:
          return 'الناخبون';
        case 2:
          return 'الوكلاء';
        default:
          return 'Vote IQ';
      }
    } else {
      switch (_currentIndex) {
        case 0:
          return 'الناخبون';
        case 1:
          return 'لوحة المتابعة';
        default:
          return 'Vote IQ';
      }
    }
  }

  Widget _buildBody(bool isAdmin) {
    if (isAdmin) {
      switch (_currentIndex) {
        case 0:
          return const DashboardScreen();
        case 1:
          return const VotersListScreen(isAdmin: true);
        case 2:
          return BlocProvider(
            create: (_) => sl<AgentsCubit>(),
            child: const AgentsListScreen(),
          );
        default:
          return const SizedBox.shrink();
      }
    } else {
      switch (_currentIndex) {
        case 0:
          return const VotersListScreen(isAdmin: false);
        case 1:
          return const DashboardScreen();
        default:
          return const SizedBox.shrink();
      }
    }
  }

  Widget _buildSyncIndicator(SyncIdle state) {
    IconData icon;
    Color color;
    String tooltip;

    switch (state.status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done_rounded;
        color = AppColors.online;
        tooltip = 'متصل ومتزامن';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync_rounded;
        color = AppColors.syncing;
        tooltip = 'جاري المزامنة...';
        break;
      case SyncStatus.offline:
        icon = Icons.cloud_off_rounded;
        color = AppColors.offline;
        tooltip = 'غير متصل (${state.pendingCount} عملية معلقة)';
        break;
      case SyncStatus.error:
        icon = Icons.error_outline;
        color = AppColors.error;
        tooltip = 'خطأ في المزامنة (${state.pendingCount} عملية معلقة)';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: tooltip,
        child: Badge(
          isLabelVisible: state.pendingCount > 0,
          label: Text('${state.pendingCount}'),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isAdmin) {
    if (isAdmin) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark,
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
          border: const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _handleTabSelection,
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'المتابعة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'الناخبون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield_rounded),
              label: 'الوكلاء',
            ),
          ],
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark,
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
          border: const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _handleTabSelection,
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'الناخبون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'المتابعة',
            ),
          ],
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  void _handleTabSelection(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);

    final isAdmin = widget.agent.isAdmin;
    final dashboardTabIndex = isAdmin ? 0 : 1;

    // Refresh the target tab's data to reflect any changes
    if (index == dashboardTabIndex) {
      context.read<DashboardCubit>().refreshStats();
    }
  }

  void _handleAppResume() {
    if (!_wasBackgrounded) {
      return;
    }
    _wasBackgrounded = false;

    final now = DateTime.now();
    final shouldHardRefresh =
        _lastBackgroundAt != null &&
        now.difference(_lastBackgroundAt!) >= _hardRefreshAfterBackground;

    if (shouldHardRefresh) {
      _refreshActiveTab(
        forceRefresh: true,
        restartRealtime: true,
        bypassThrottle: true,
      );
    }
  }

  void _handlePermissionChange() {
    debugPrint('[HomeScreen] current user permissions changed');
    sl<SupabaseVoterDatasource>().invalidatePermissionsCache();
    sl<SupabaseLookupDatasource>().invalidatePermissionsCache();
    _refreshActiveTab(
      forceRefresh: true,
      restartRealtime: true,
      bypassThrottle: true,
    );
  }

  Future<void> _refreshActiveTab({
    bool forceRefresh = false,
    bool restartRealtime = false,
    bool bypassThrottle = false,
  }) async {
    if (!mounted) return;

    final now = DateTime.now();
    if (!bypassThrottle &&
        _lastAutoRefreshAt != null &&
        now.difference(_lastAutoRefreshAt!) < _autoRefreshThrottle) {
      return;
    }
    _lastAutoRefreshAt = now;

    final isAdmin = widget.agent.isAdmin;
    final votersTabIndex = isAdmin ? 1 : 0;
    final dashboardTabIndex = isAdmin ? 0 : 1;

    if (_currentIndex == votersTabIndex) {
      if (forceRefresh || restartRealtime) {
        await context.read<VotersCubit>().refreshCurrentView(
          forceRefresh: forceRefresh,
          restartRealtime: restartRealtime,
        );
      }
      return;
    }

    if (_currentIndex == dashboardTabIndex) {
      if (forceRefresh || restartRealtime) {
        await context.read<VotersCubit>().refreshCurrentView(
          forceRefresh: forceRefresh,
          restartRealtime: restartRealtime,
        );
        if (!mounted) return;
      }
      await context.read<DashboardCubit>().refreshStats();
    }
  }
}

class _HomeLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResume;
  final VoidCallback? onPause;

  _HomeLifecycleObserver({required this.onResume, this.onPause});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (onPause != null) {
        onPause!();
      }
    }
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
