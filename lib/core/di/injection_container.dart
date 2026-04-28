import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/local/local_lookup_datasource.dart';
import '../../data/datasources/local/local_voter_datasource.dart';
import '../../data/datasources/remote/supabase_agent_datasource.dart';
import '../../data/datasources/remote/supabase_auth_datasource.dart';
import '../../data/datasources/remote/supabase_lookup_datasource.dart';
import '../../data/datasources/remote/supabase_voter_datasource.dart';
import '../../data/repositories/agent_repository_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/lookup_repository_impl.dart';
import '../../data/repositories/voter_repository_impl.dart';
import '../../data/services/list_candidate_import_service.dart';
import '../../data/services/voter_import_service.dart';
import '../../domain/usecases/lookup/import_lists_candidates_usecase.dart';
import '../../data/sync/conflict_resolver.dart';
import '../../data/sync/sync_manager.dart';
import '../../data/sync/sync_queue.dart';
import '../../domain/repositories/agent_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/lookup_repository.dart';
import '../../domain/repositories/voter_repository.dart';
import '../../domain/usecases/agent/agent_core_usecases.dart';
import '../../domain/usecases/agent/agent_permission_usecases.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/voter/get_voter_stats_usecase.dart';
import '../../domain/usecases/voter/get_voters_usecase.dart';
import '../../domain/usecases/voter/search_voters_usecase.dart';
import '../../domain/usecases/voter/update_voter_status_usecase.dart';
import '../../domain/usecases/voter/voter_crud_usecases.dart';
import '../../domain/usecases/lookup/lookup_crud_usecases.dart';
import '../../presentation/agents/cubit/agents_cubit.dart';
import '../../presentation/auth/cubit/auth_cubit.dart';
import '../../presentation/dashboard/cubit/dashboard_cubit.dart';
import '../../presentation/sync/cubit/sync_cubit.dart';
import '../../presentation/voters/cubit/voters_cubit.dart';
import '../../presentation/lookup/cubit/lookup_cubit.dart';
import '../utils/connectivity_helper.dart';

/// Global service locator instance.
final sl = GetIt.instance;

/// Initialize all dependencies.
Future<void> initDependencies() async {
  final supabaseClient = Supabase.instance.client;

  // ── Core ──
  sl.registerLazySingleton<ConnectivityHelper>(() => ConnectivityHelper());

  // ── Datasources (Remote) ──
  sl.registerLazySingleton<SupabaseAuthDatasource>(
    () => SupabaseAuthDatasource(supabaseClient),
  );
  sl.registerLazySingleton<SupabaseAgentDatasource>(
    () => SupabaseAgentDatasource(supabaseClient),
  );
  sl.registerLazySingleton<SupabaseVoterDatasource>(
    () => SupabaseVoterDatasource(supabaseClient),
  );
  sl.registerLazySingleton<SupabaseLookupDatasource>(
    () => SupabaseLookupDatasource(supabaseClient),
  );

  // ── Datasources (Local) ──
  sl.registerLazySingleton<LocalVoterDatasource>(
    () => LocalVoterDatasource(),
  );
  sl.registerLazySingleton<LocalLookupDatasource>(
    () => LocalLookupDatasource(),
  );

  // ── Sync ──
  sl.registerLazySingleton<SyncQueue>(() => SyncQueue());
  sl.registerLazySingleton<ConflictResolver>(
    () => ConflictResolver(sl<SupabaseVoterDatasource>()),
  );
  sl.registerLazySingleton<SyncManager>(
    () => SyncManager(
      syncQueue: sl<SyncQueue>(),
      remoteDatasource: sl<SupabaseVoterDatasource>(),
      localDatasource: sl<LocalVoterDatasource>(),
      conflictResolver: sl<ConflictResolver>(),
      connectivity: sl<ConnectivityHelper>(),
    ),
  );

  // ── Repositories ──
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDatasource: sl<SupabaseAuthDatasource>(),
      lookupRepository: sl<LookupRepository>(),
      syncQueue: sl<SyncQueue>(),
      voterDatasource: sl<SupabaseVoterDatasource>(),
      lookupDatasource: sl<SupabaseLookupDatasource>(),
      agentDatasource: sl<SupabaseAgentDatasource>(),
    ),
  );
  sl.registerLazySingleton<AgentRepository>(
    () => AgentRepositoryImpl(
      remoteDatasource: sl<SupabaseAgentDatasource>(),
      connectivity: sl<ConnectivityHelper>(),
    ),
  );
  sl.registerLazySingleton<VoterRepository>(
    () => VoterRepositoryImpl(
      remoteDatasource: sl<SupabaseVoterDatasource>(),
      authDatasource: sl<SupabaseAuthDatasource>(),
      lookupRemote: sl<SupabaseLookupDatasource>(),
      localDatasource: sl<LocalVoterDatasource>(),
      syncQueue: sl<SyncQueue>(),
      syncManager: sl<SyncManager>(),
      connectivity: sl<ConnectivityHelper>(),
      importService: sl<VoterImportService>(),
    ),
  );
  sl.registerLazySingleton<LookupRepository>(
    () => LookupRepositoryImpl(
      remoteDatasource: sl<SupabaseLookupDatasource>(),
      localDatasource: sl<LocalLookupDatasource>(),
      connectivity: sl<ConnectivityHelper>(),
      importService: sl<ListCandidateImportService>(),
    ),
  );

  // ── Use Cases ──
  sl.registerLazySingleton(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(sl<AuthRepository>(), sl<VoterRepository>()));
  sl.registerLazySingleton(() => GetVotersUseCase(sl<VoterRepository>()));
  sl.registerLazySingleton(() => SearchVotersUseCase(sl<VoterRepository>()));
  sl.registerLazySingleton(
      () => UpdateVoterStatusUseCase(sl<VoterRepository>()));
  sl.registerLazySingleton(() => GetVoterStatsUseCase(sl<VoterRepository>()));
  
  // Voter CRUD
  sl.registerLazySingleton(() => CreateVoterUseCase(sl<VoterRepository>()));
  sl.registerLazySingleton(() => UpdateVoterUseCase(sl<VoterRepository>()));
  sl.registerLazySingleton(() => DeleteVoterUseCase(sl<VoterRepository>()));
  sl.registerLazySingleton(() => ImportVotersUseCase(sl<VoterRepository>()));
  sl.registerLazySingleton(
    () => ImportVoterHouseholdDataUseCase(sl<VoterRepository>()),
  );
  sl.registerLazySingleton(
    () => ImportVoterSubClansUseCase(sl<VoterRepository>()),
  );

  // Lookup CRUD
  sl.registerLazySingleton(() => AddFamilyUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => DeleteFamilyUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => AddSubClanUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => DeleteSubClanUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => AddVotingCenterUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => DeleteVotingCenterUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => AddElectoralListUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => DeleteElectoralListUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => AddCandidateUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => DeleteCandidateUseCase(sl<LookupRepository>()));
  sl.registerLazySingleton(() => ImportListsCandidatesUseCase(sl<LookupRepository>()));


  // Agent Use Cases
  sl.registerLazySingleton(() => GetAgentsUseCase(sl<AgentRepository>()));
  sl.registerLazySingleton(() => CreateAgentUseCase(sl<AgentRepository>()));
  sl.registerLazySingleton(() => UpdateAgentStatusUseCase(sl<AgentRepository>()));
  sl.registerLazySingleton(() => DeleteAgentUseCase(sl<AgentRepository>()));
  sl.registerLazySingleton(() => GetAgentPermissionsUseCase(sl<AgentRepository>()));
  sl.registerLazySingleton(() => AddAgentPermissionUseCase(sl<AgentRepository>()));
  sl.registerLazySingleton(() => RemoveAgentPermissionUseCase(sl<AgentRepository>()));

  // ── Cubits ──
  sl.registerFactory<AuthCubit>(
    () => AuthCubit(
      loginUseCase: sl<LoginUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      authRepository: sl<AuthRepository>(),
    ),
  );
  sl.registerFactory<VotersCubit>(
    () => VotersCubit(
      getVotersUseCase: sl<GetVotersUseCase>(),
      searchVotersUseCase: sl<SearchVotersUseCase>(),
      updateVoterStatusUseCase: sl<UpdateVoterStatusUseCase>(),
      createVoterUseCase: sl<CreateVoterUseCase>(),
      updateVoterUseCase: sl<UpdateVoterUseCase>(),
      deleteVoterUseCase: sl<DeleteVoterUseCase>(),
      importVotersUseCase: sl<ImportVotersUseCase>(),
      importVoterHouseholdDataUseCase: sl<ImportVoterHouseholdDataUseCase>(),
      importVoterSubClansUseCase: sl<ImportVoterSubClansUseCase>(),
      voterRepository: sl<VoterRepository>(),
    ),
  );
  sl.registerFactory<DashboardCubit>(
    () => DashboardCubit(
      getVoterStatsUseCase: sl<GetVoterStatsUseCase>(),
      lookupRepository: sl<LookupRepository>(),
      voterRepository: sl<VoterRepository>(),
    ),
  );
  sl.registerFactory<SyncCubit>(
    () => SyncCubit(
      syncManager: sl<SyncManager>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );
  sl.registerFactory<AgentsCubit>(
    () => AgentsCubit(
      getAgents: sl<GetAgentsUseCase>(),
      createAgent: sl<CreateAgentUseCase>(),
      updateAgentStatus: sl<UpdateAgentStatusUseCase>(),
      deleteAgent: sl<DeleteAgentUseCase>(),
      getPermissions: sl<GetAgentPermissionsUseCase>(),
      addPermission: sl<AddAgentPermissionUseCase>(),
      removePermission: sl<RemoveAgentPermissionUseCase>(),
    ),
  );
  
  sl.registerFactory<LookupCubit>(
    () => LookupCubit(
      lookupRepository: sl<LookupRepository>(),
      addFamily: sl<AddFamilyUseCase>(),
      deleteFamily: sl<DeleteFamilyUseCase>(),
      addSubClan: sl<AddSubClanUseCase>(),
      deleteSubClan: sl<DeleteSubClanUseCase>(),
      addVotingCenter: sl<AddVotingCenterUseCase>(),
      deleteVotingCenter: sl<DeleteVotingCenterUseCase>(),
      addElectoralList: sl<AddElectoralListUseCase>(),
      deleteElectoralList: sl<DeleteElectoralListUseCase>(),
      addCandidate: sl<AddCandidateUseCase>(),
      deleteCandidate: sl<DeleteCandidateUseCase>(),
      importListsCandidates: sl<ImportListsCandidatesUseCase>(),
    ),
  );

  // ── Services ──
  sl.registerLazySingleton(() => VoterImportService());
  sl.registerLazySingleton(() => ListCandidateImportService());
}
