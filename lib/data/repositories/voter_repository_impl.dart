import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/connectivity_helper.dart';
import '../../../domain/entities/voter.dart';
import '../../../domain/repositories/voter_repository.dart';
import '../datasources/local/local_voter_datasource.dart';
import '../datasources/remote/supabase_auth_datasource.dart';
import '../datasources/remote/supabase_voter_datasource.dart';
import '../datasources/remote/supabase_lookup_datasource.dart';
import '../models/voter_model.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue.dart';
import '../services/voter_import_service.dart';

/// Voter repository implementation — offline-first strategy.
class VoterRepositoryImpl implements VoterRepository {
  final SupabaseVoterDatasource _remoteDatasource;
  final SupabaseAuthDatasource _authDatasource;
  final SupabaseLookupDatasource _lookupRemote;
  final LocalVoterDatasource _localDatasource;
  final SyncQueue _syncQueue;
  final SyncManager _syncManager;
  final ConnectivityHelper _connectivity;
  final VoterImportService _importService;

  bool _isDataLoaded = false;
  DateTime? _lastSyncTime;
  bool _isFirstLoad = true;
  String? _loadedForUserId;
  static const Duration _syncInterval = Duration(minutes: 5);
  Future<void>? _cachePrimingFuture;
  late final Stream<Voter> _sharedVoterChanges = _remoteDatasource.voterChanges
      .asyncMap((model) async {
        final cached = await _localDatasource.getCachedVoter(model.voterSymbol);
        final mergedModel = _mergeRealtimeVoter(model, cached);
        await _localDatasource.updateCachedVoter(mergedModel);
        return mergedModel.toEntity();
      })
      .asBroadcastStream();

  VoterRepositoryImpl({
    required SupabaseVoterDatasource remoteDatasource,
    required SupabaseAuthDatasource authDatasource,
    required SupabaseLookupDatasource lookupRemote,
    required LocalVoterDatasource localDatasource,
    required SyncQueue syncQueue,
    required SyncManager syncManager,
    required ConnectivityHelper connectivity,
    required VoterImportService importService,
  }) : _remoteDatasource = remoteDatasource,
       _authDatasource = authDatasource,
       _lookupRemote = lookupRemote,
       _localDatasource = localDatasource,
       _syncQueue = syncQueue,
       _syncManager = syncManager,
       _connectivity = connectivity,
       _importService = importService {
    _initBackgroundSync();
  }

  Future<DateTime?> _getLastSyncTime() async {
    try {
      final box = await Hive.openBox(AppConstants.hiveSettingsBox);
      final timestamp = box.get('last_sync_time_$_loadedForUserId') as int?;
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    try {
      final box = await Hive.openBox(AppConstants.hiveSettingsBox);
      await box.put(
        'last_sync_time_$_loadedForUserId',
        time.millisecondsSinceEpoch,
      );
      _lastSyncTime = time;
    } catch (_) {}
  }

  void _initBackgroundSync() {
    Future.doWhile(() async {
      await Future.delayed(_syncInterval);
      if (await _connectivity.hasInternet) {
        await _syncIncrementalChanges();
      }
      return true;
    });
  }

  Future<void> _syncIncrementalChanges() async {
    if (_lastSyncTime == null || !_isDataLoaded) return;
    try {
      final updatedVoters = await _remoteDatasource.getVotersUpdatedAfter(
        _lastSyncTime!,
      );
      if (updatedVoters.isNotEmpty) {
        await _localDatasource.cacheVoters(updatedVoters);
        await _setLastSyncTime(DateTime.now());
      }
    } catch (e) {
      debugPrint('Repository: Sync error: $e');
    }
  }

  Future<void> _resetScopedCacheForCurrentUser() async {
    debugPrint('Repository: Resetting scoped voter cache for user switch');
    await _localDatasource.clearCache();
    _lastSyncTime = null;
    _isDataLoaded = false;
    _isFirstLoad = true;
  }

  Future<void> _ensureCurrentUserScope() async {
    final currentUserId = _authDatasource.currentUserId;
    if (currentUserId == null) {
      if (_loadedForUserId != null) {
        await _resetScopedCacheForCurrentUser();
        _loadedForUserId = null;
      }
      return;
    }

    if (_loadedForUserId != currentUserId) {
      debugPrint(
        'Repository: User scope changed from $_loadedForUserId to $currentUserId',
      );
      // Only clear cache if we actually switched from a previous logged-in user to a DIFFERENT user
      // If _loadedForUserId is null, it's a cold boot, so keep the offline cache!
      if (_loadedForUserId != null) {
        await _resetScopedCacheForCurrentUser();
      }
      _loadedForUserId = currentUserId;
      _lastSyncTime = await _getLastSyncTime();
      if (_lastSyncTime != null) {
        _isDataLoaded = true;
        _isFirstLoad = false;
      }
    } else {
      debugPrint('Repository: User scope unchanged for $currentUserId');
    }
  }

  Future<List<VoterModel>> _loadAllDataFromServer() async {
    final allVoters = await _remoteDatasource.getAllVoters();
    debugPrint(
      'Repository: _loadAllDataFromServer fetched ${allVoters.length} voters',
    );
    await _localDatasource.clearCache();
    await _localDatasource.cacheVoters(allVoters);
    await _setLastSyncTime(DateTime.now());
    _isDataLoaded = true;
    _isFirstLoad = false;
    return allVoters;
  }

  Future<void> _ensureStatsCacheReady() async {
    await _ensureCurrentUserScope();

    if (_cachePrimingFuture != null) {
      debugPrint('Repository: waiting for existing cache priming before stats');
      await _cachePrimingFuture;
      return;
    }

    final localCount = await _localDatasource.getVotersCount();
    final hasInternet = await _connectivity.hasInternet;
    debugPrint(
      'Repository: ensureStatsCacheReady '
      'localCount=$localCount, hasInternet=$hasInternet, '
      'isDataLoaded=$_isDataLoaded',
    );

    if (localCount > 0) {
      if (!_isDataLoaded) {
        _isDataLoaded = true;
        _isFirstLoad = false;
      }
      return;
    }

    if (!hasInternet) {
      debugPrint('Repository: stats cache is empty and no internet available');
      return;
    }

    _cachePrimingFuture = () async {
      debugPrint('Repository: priming stats cache from server');
      await _loadAllDataFromServer();
    }();

    try {
      await _cachePrimingFuture;
    } finally {
      _cachePrimingFuture = null;
    }
  }

  @override
  Future<Either<Failure, List<Voter>>> getVoters(
    VoterFilter filter, {
    bool forceRefresh = false,
  }) async {
    try {
      await _ensureCurrentUserScope();
      // Check local data first
      final localCount = await _localDatasource.getVotersCount();
      final hasInternet = await _connectivity.hasInternet;
      debugPrint(
        'Repository: getVoters start '
        'localCount=$localCount, hasInternet=$hasInternet, '
        'isDataLoaded=$_isDataLoaded, forceRefresh=$forceRefresh, '
        'loadedForUser=$_loadedForUserId',
      );

      List<VoterModel>? freshlyLoadedFromServer;

      if (hasInternet) {
        if (_cachePrimingFuture != null) {
          debugPrint(
            'Repository: getVoters waiting for existing cache priming',
          );
          await _cachePrimingFuture;
        }
        // Online mode: if completely empty cache, fetch one page to unblock UI then background sync full DB
        if (localCount == 0 && forceRefresh == false) {
          debugPrint('Repository: Cache empty, fetching first page instantly to unblock UI');
          freshlyLoadedFromServer = await _remoteDatasource.getVoters(
            VoterFilter(
              familyIds: filter.familyIds,
              subClanId: filter.subClanId,
              centerId: filter.centerId,
              status: filter.status,
              searchQuery: filter.searchQuery,
              page: 0,
              pageSize: 50,
            ),
          );
          await _localDatasource.cacheVoters(freshlyLoadedFromServer);

          // Trigger full background sync without awaiting
          _cachePrimingFuture = _loadAllDataFromServer().then((_) {
            debugPrint('Repository: Background cache priming complete');
          }).catchError((e) {
            debugPrint('Repository: Background cache priming failed: $e');
          });
        }
        else if (!_isDataLoaded || localCount == 0 || forceRefresh) {
          // Forced refresh - load all from server
          freshlyLoadedFromServer = await _loadAllDataFromServer();
        } else if (_lastSyncTime != null && !_isFirstLoad) {
          // Sync incremental changes only
          await _syncIncrementalChanges();
        }
      }

      // Always use local data (whether online or offline)
      final models = await _localDatasource.getCachedVoters(
        familyIds: filter.familyIds,
        subClanId: filter.subClanId,
        centerId: filter.centerId,
        status: filter.status,
        searchQuery: filter.searchQuery,
        page: filter.page,
        pageSize: filter.pageSize,
      );
      debugPrint(
        'Repository: getVoters local result count=${models.length} '
        'familyIds=${filter.familyIds}, subClanId=${filter.subClanId}, '
        'centerId=${filter.centerId}, status=${filter.status}, '
        'searchQuery=${filter.searchQuery}',
      );

      final noExplicitFilters =
          (filter.familyIds == null || filter.familyIds!.isEmpty) &&
          filter.subClanId == null &&
          filter.centerId == null &&
          filter.status == null &&
          (filter.searchQuery == null || filter.searchQuery!.isEmpty);

      if (models.isEmpty &&
          freshlyLoadedFromServer != null &&
          freshlyLoadedFromServer.isNotEmpty &&
          noExplicitFilters) {
        debugPrint(
          'Repository: local cache empty after fresh server load, '
          'returning freshly loaded server data directly',
        );
        return Right(freshlyLoadedFromServer.map((m) => m.toEntity()).toList());
      }

      if (models.isEmpty && hasInternet && !forceRefresh && noExplicitFilters) {
        debugPrint(
          'Repository: local result empty despite no filters, retrying with forced server reload',
        );
        final reloadedFromServer = await _loadAllDataFromServer();
        final reloadedModels = await _localDatasource.getCachedVoters(
          familyIds: filter.familyIds,
          subClanId: filter.subClanId,
          centerId: filter.centerId,
          status: filter.status,
          searchQuery: filter.searchQuery,
          page: filter.page,
          pageSize: filter.pageSize,
        );
        debugPrint(
          'Repository: getVoters result after forced reload count=${reloadedModels.length}',
        );
        if (reloadedModels.isEmpty &&
            reloadedFromServer.isNotEmpty &&
            noExplicitFilters) {
          debugPrint(
            'Repository: forced reload cache still empty, '
            'returning server data directly',
          );
          return Right(reloadedFromServer.map((m) => m.toEntity()).toList());
        }
        return Right(reloadedModels.map((m) => m.toEntity()).toList());
      }
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      debugPrint('Repository: getVoters exception: $e');
      // Try cache fallback
      try {
        final models = await _localDatasource.getCachedVoters(
          familyIds: filter.familyIds,
          subClanId: filter.subClanId,
          centerId: filter.centerId,
          status: filter.status,
          searchQuery: filter.searchQuery,
          page: filter.page,
          pageSize: filter.pageSize,
        );
        debugPrint(
          'Repository: getVoters fallback local result count=${models.length}',
        );
        return Right(models.map((m) => m.toEntity()).toList());
      } catch (_) {
        return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
      }
    }
  }

  @override
  Future<Either<Failure, List<Voter>>> searchVoters(String query) async {
    try {
      await _ensureCurrentUserScope();
      // Always use local cache for fast searching
      final models = await _localDatasource.getCachedVoters(
        searchQuery: query,
        pageSize: 0,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في البحث: $e'));
    }
  }

  bool _isLikelyConnectivityFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection closed') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('os error');
  }

  Future<Either<Failure, Voter>> _queueOfflineStatusUpdate({
    required String voterSymbol,
    required String newStatus,
    required String? refusalReason,
    int? listId,
    int? candidateId,
    required String agentId,
  }) async {
    final now = DateTime.now();
    final operation = SyncOperation(
      id: '${voterSymbol}_${now.millisecondsSinceEpoch}',
      voterSymbol: voterSymbol,
      newStatus: newStatus,
      refusalReason: refusalReason,
      listId: listId,
      candidateId: candidateId,
      agentId: agentId,
      timestamp: now,
    );
    await _syncQueue.enqueue(operation);
    debugPrint(
      'Repository: updateVoterStatus queued offline operation '
      'voterSymbol=$voterSymbol, status=$newStatus',
    );

    if (await _connectivity.hasInternet) {
      debugPrint(
        'Repository: updateVoterStatus queued operation will try immediate sync '
        'voterSymbol=$voterSymbol',
      );
      unawaited(_syncManager.syncPendingOperations());
    }

    final cachedVoter = await _localDatasource.getCachedVoter(voterSymbol);
    if (cachedVoter != null) {
      final updated = VoterModel(
        voterSymbol: cachedVoter.voterSymbol,
        firstName: cachedVoter.firstName,
        fatherName: cachedVoter.fatherName,
        grandfatherName: cachedVoter.grandfatherName,
        familyId: cachedVoter.familyId,
        subClanId: cachedVoter.subClanId,
        centerId: cachedVoter.centerId,
        listId: newStatus == AppConstants.statusVoted ? listId : null,
        candidateId: newStatus == AppConstants.statusVoted ? candidateId : null,
        status: newStatus,
        refusalReason: refusalReason,
        updatedAt: now,
        updatedBy: agentId,
        familyName: cachedVoter.familyName,
        subClanName: cachedVoter.subClanName,
        centerName: cachedVoter.centerName,
        listName:
            newStatus == AppConstants.statusVoted &&
                listId == cachedVoter.listId
            ? cachedVoter.listName
            : null,
        candidateName:
            newStatus == AppConstants.statusVoted &&
                candidateId == cachedVoter.candidateId
            ? cachedVoter.candidateName
            : null,
      );
      await _localDatasource.updateCachedVoter(updated);
      return Right(updated.toEntity());
    }

    return Right(
      Voter(
        voterSymbol: voterSymbol,
        listId: newStatus == AppConstants.statusVoted ? listId : null,
        candidateId: newStatus == AppConstants.statusVoted ? candidateId : null,
        status: newStatus,
        refusalReason: refusalReason,
        updatedAt: now,
        updatedBy: agentId,
      ),
    );
  }

  @override
  Future<Either<Failure, Voter>> updateVoterStatus({
    required String voterSymbol,
    required String newStatus,
    String? refusalReason,
    int? listId,
    int? candidateId,
  }) async {
    final agentId = _authDatasource.currentUserId;
    if (agentId == null) {
      return const Left(AuthFailure(message: 'غير مسجل الدخول'));
    }

    try {
      debugPrint(
        'Repository: updateVoterStatus start '
        'voterSymbol=$voterSymbol, status=$newStatus',
      );

      final model = await _remoteDatasource.updateVoterStatus(
        voterSymbol: voterSymbol,
        newStatus: newStatus,
        refusalReason: refusalReason,
        listId: listId,
        candidateId: candidateId,
        agentId: agentId,
      );

      // Merge with cached lookup names since the update returns basic fields only
      final mergedModel = _mergeRealtimeVoter(
        model,
        await _localDatasource.getCachedVoter(voterSymbol),
      );
      await _localDatasource.updateCachedVoter(mergedModel);
      debugPrint(
        'Repository: updateVoterStatus committed directly to Supabase '
        'voterSymbol=$voterSymbol, status=${mergedModel.status}',
      );
      return Right(mergedModel.toEntity());
    } on ServerException catch (e) {
      final stillOnline = await _connectivity.hasInternet;

      if (stillOnline && _isLikelyConnectivityFailure(e.message)) {
        debugPrint(
          'Repository: updateVoterStatus retrying remote commit once '
          'voterSymbol=$voterSymbol, message=${e.message}',
        );

        try {
          final retriedModel = await _remoteDatasource.updateVoterStatus(
            voterSymbol: voterSymbol,
            newStatus: newStatus,
            refusalReason: refusalReason,
            listId: listId,
            candidateId: candidateId,
            agentId: agentId,
          );
          final mergedRetry = _mergeRealtimeVoter(
            retriedModel,
            await _localDatasource.getCachedVoter(voterSymbol),
          );
          await _localDatasource.updateCachedVoter(mergedRetry);
          debugPrint(
            'Repository: updateVoterStatus committed after retry '
            'voterSymbol=$voterSymbol, status=${mergedRetry.status}',
          );
          return Right(mergedRetry.toEntity());
        } on ServerException catch (retryError) {
          debugPrint(
            'Repository: updateVoterStatus retry failed '
            'voterSymbol=$voterSymbol, message=${retryError.message}',
          );
          if (!_isLikelyConnectivityFailure(retryError.message)) {
            return Left(ServerFailure(message: retryError.message));
          }
        }
      }

      if (!stillOnline || _isLikelyConnectivityFailure(e.message)) {
        debugPrint(
          'Repository: updateVoterStatus falling back to offline queue '
          'voterSymbol=$voterSymbol, message=${e.message}',
        );
        return _queueOfflineStatusUpdate(
          voterSymbol: voterSymbol,
          newStatus: newStatus,
          refusalReason: refusalReason,
          listId: listId,
          candidateId: candidateId,
          agentId: agentId,
        );
      }
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في تحديث الحالة: $e'));
    }
  }

  @override
  Future<Either<Failure, VoterStats>> getVoterStats({
    int? familyId,
    int? subClanId,
    int? centerId,
  }) async {
    try {
      await _ensureStatsCacheReady();
      // Use local cache for ALL statistics since it's fully synced.
      // Doing this prevents 100+ parallel requests to Supabase which causes "list map" failure or socket timeout.
      final cached = await _localDatasource.getCachedStats(
        familyId: familyId,
        subClanId: subClanId,
        centerId: centerId,
      );
      final total = cached['total'] ?? 0;
      final voted = cached['voted'] ?? 0;
      return Right(
        VoterStats(
          total: total,
          voted: voted,
          refused: cached['refused'] ?? 0,
          notVoted: cached['notVoted'] ?? 0,
          votedPercentage: total > 0 ? (voted / total) * 100 : 0,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في الإحصائيات: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<int, VoterStats>>> getFamilyStatsBatch(
    List<int> familyIds,
  ) async {
    try {
      await _ensureStatsCacheReady();
      final grouped = await _localDatasource.getGroupedCachedStats(
        groupField: 'family_id',
        allowedIds: familyIds,
      );
      return Right(_mapGroupedStats(grouped));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في إحصائيات العائلات: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<int, VoterStats>>> getSubClanStatsBatch(
    List<int> subClanIds,
  ) async {
    try {
      await _ensureStatsCacheReady();
      final grouped = await _localDatasource.getGroupedCachedStats(
        groupField: 'sub_clan_id',
        allowedIds: subClanIds,
      );
      return Right(_mapGroupedStats(grouped));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في إحصائيات الفروع: $e'));
    }
  }

  Map<int, VoterStats> _mapGroupedStats(Map<int, Map<String, int>> grouped) {
    final result = <int, VoterStats>{};

    for (final entry in grouped.entries) {
      final total = entry.value['total'] ?? 0;
      final voted = entry.value['voted'] ?? 0;
      result[entry.key] = VoterStats(
        total: total,
        voted: voted,
        refused: entry.value['refused'] ?? 0,
        notVoted: entry.value['notVoted'] ?? 0,
        votedPercentage: total > 0 ? (voted / total) * 100 : 0,
      );
    }

    return result;
  }

  VoterModel _mergeRealtimeVoter(VoterModel incoming, VoterModel? cached) {
    if (cached == null) {
      return incoming;
    }

    return VoterModel(
      voterSymbol: incoming.voterSymbol,
      firstName: incoming.firstName ?? cached.firstName,
      fatherName: incoming.fatherName ?? cached.fatherName,
      grandfatherName: incoming.grandfatherName ?? cached.grandfatherName,
      familyId: incoming.familyId ?? cached.familyId,
      subClanId: incoming.subClanId ?? cached.subClanId,
      centerId: incoming.centerId ?? cached.centerId,
      listId: incoming.listId ?? cached.listId,
      candidateId: incoming.candidateId ?? cached.candidateId,
      status: incoming.status,
      refusalReason: incoming.refusalReason,
      updatedAt: incoming.updatedAt ?? cached.updatedAt,
      updatedBy: incoming.updatedBy ?? cached.updatedBy,
      familyName: incoming.familyName ?? cached.familyName,
      subClanName: incoming.subClanName ?? cached.subClanName,
      centerName: incoming.centerName ?? cached.centerName,
      listName: incoming.listName ?? cached.listName,
      candidateName: incoming.candidateName ?? cached.candidateName,
    );
  }

  @override
  Future<Either<Failure, Voter>> createVoter(Voter voter) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'),
        );
      }
      final model = VoterModel.fromEntity(voter);
      final result = await _remoteDatasource.createVoter(model);
      await _localDatasource.updateCachedVoter(result);
      return Right(result.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, Voter>> updateVoter(Voter voter) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'),
        );
      }
      final model = VoterModel.fromEntity(voter);
      final result = await _remoteDatasource.updateVoter(model);
      await _localDatasource.updateCachedVoter(result);
      return Right(result.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteVoter(String voterSymbol) async {
    try {
      if (!await _connectivity.hasInternet) {
        return const Left(
          ServerFailure(message: 'تتطلب هذه العملية اتصالاً بالانترنت'),
        );
      }
      await _remoteDatasource.deleteVoter(voterSymbol);
      // Wait for cache to clear for this symbol? Or just let it be.
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ غير متوقع: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> importVoters(String filePath) async {
    try {
      print('DEBUG: VoterRepository: Starting import for file: $filePath');
      if (!await _connectivity.hasInternet) {
        print('DEBUG: VoterRepository: No internet connection detected.');
        return const Left(
          ServerFailure(
            message: 'تتطلب هذه العملية اتصالاً بالانترنت للاستيراد الجماعي',
          ),
        );
      }

      final parsedVoters = await _importService.parseVotersExcel(filePath);
      print(
        'DEBUG: VoterRepository: Parsed \${parsedVoters.length} voters from Excel.',
      );

      if (parsedVoters.isEmpty) {
        return const Left(
          ServerFailure(message: 'لم يتم العثور على بيانات صالحة في الملف'),
        );
      }

      // 1. Fetch current lookups to map names to IDs
      print('DEBUG: VoterRepository: Fetching lookups for mapping...');
      final families = await _lookupRemote.getFamilies();
      final familyMap = {for (var f in families) f.familyName.trim(): f.id};

      final centers = await _lookupRemote.getVotingCenters();
      final centerMap = {for (var c in centers) c.centerName.trim(): c.id};

      // Sub-clans are trickier (unique by name+family)
      final allSubClans = await _lookupRemote.getSubClans();
      final subClanMap = <String, int>{}; // "familyId_name" -> sub_clan_id
      for (var s in allSubClans) {
        subClanMap['\${s.familyId}_\${s.subName.trim()}'] = s.id;
      }

      print(
        'DEBUG: VoterRepository: Lookups fetched. families: \${families.length}, centers: \${centers.length}, subClans: \${allSubClans.length}',
      );

      // --------- DYNAMIC LOOKUP INSERTION ---------
      print('DEBUG: VoterRepository: Dynamically creating missing lookups...');

      // 1. Centers
      final uniqueCenters = parsedVoters
          .map((v) => v.centerName?.trim())
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet();
      for (final center in uniqueCenters) {
        if (!centerMap.containsKey(center)) {
          print('DEBUG: Creating missing center: \$center');
          final newCenter = await _lookupRemote.addVotingCenter(center);
          centerMap[center] = newCenter.id;
        }
      }

      // 2. Families
      final uniqueFamilies = parsedVoters
          .map((v) => v.familyName?.trim())
          .where((f) => f != null && f.isNotEmpty)
          .cast<String>()
          .toSet();
      for (final family in uniqueFamilies) {
        if (!familyMap.containsKey(family)) {
          print('DEBUG: Creating missing family: \$family');
          final newFamily = await _lookupRemote.addFamily(family);
          familyMap[family] = newFamily.id;
        }
      }

      // 3. Sub-clans
      final uniqueSubClansKeys = <String>{};
      for (final v in parsedVoters) {
        final fName = v.familyName?.trim();
        final sName = v.subClanName?.trim();
        if (fName != null &&
            fName.isNotEmpty &&
            sName != null &&
            sName.isNotEmpty) {
          uniqueSubClansKeys.add('\$fName|\$sName');
        }
      }
      for (final key in uniqueSubClansKeys) {
        final parts = key.split('|');
        final fName = parts[0];
        final sName = parts[1];
        final fId = familyMap[fName];
        if (fId != null) {
          final mapKey = '\${fId}_\$sName';
          if (!subClanMap.containsKey(mapKey)) {
            print(
              'DEBUG: Creating missing sub-clan: \$sName for family: \$fName',
            );
            final newSub = await _lookupRemote.addSubClan(fId, sName);
            subClanMap[mapKey] = newSub.id;
          }
        }
      }
      // ---------------------------------------------

      // 2. Map and prepare for insert
      final votersToInsert = <VoterModel>[];
      for (var v in parsedVoters) {
        int? fId = v.familyName != null
            ? familyMap[v.familyName!.trim()]
            : null;
        int? cId = v.centerName != null
            ? centerMap[v.centerName!.trim()]
            : null;
        int? sId;
        if (fId != null && v.subClanName != null) {
          sId = subClanMap['\${fId}_\${v.subClanName!.trim()}'];
        }

        votersToInsert.add(
          VoterModel(
            voterSymbol: v.voterSymbol,
            firstName: v.firstName,
            fatherName: v.fatherName,
            grandfatherName: v.grandfatherName,
            familyId: fId,
            subClanId: sId,
            centerId: cId,
            status: 'لم يصوت',
          ),
        );
      }

      print(
        'DEBUG: VoterRepository: Mapping complete. Prepared \${votersToInsert.length} voters for insertion.',
      );

      // 3. Perform bulk insert
      print('DEBUG: VoterRepository: Calling remote bulk insert...');
      await _remoteDatasource.bulkInsertVoters(votersToInsert);
      print('DEBUG: VoterRepository: Bulk insert successful.');

      return Right(votersToInsert.length);
    } on ServerException catch (e) {
      print(
        'DEBUG: VoterRepository: ServerException during import: ' + e.message,
      );
      return Left(ServerFailure(message: e.message));
    } catch (e, stack) {
      print(
        'DEBUG: VoterRepository: Unexpected Exception during import: ' +
            e.toString(),
      );
      print('DEBUG: VoterRepository: StackTrace: ' + stack.toString());
      return Left(
        ServerFailure(
          message: 'خطأ غير متوقع أثناء الاستيراد: ' + e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAllUniqueFamilies() async {
    try {
      if (await _connectivity.hasInternet) {
        final names = await _remoteDatasource.getAllUniqueFamilies();
        return Right(names);
      } else {
        final names = await _localDatasource.getAllUniqueFamilies();
        return Right(names);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب أسماء العائلات: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getFamiliesMap() async {
    try {
      if (await _connectivity.hasInternet) {
        final map = await _remoteDatasource.getFamiliesMap();
        return Right(map);
      } else {
        final map = await _localDatasource.getFamiliesMap();
        return Right(map);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب خريطة العائلات: $e'));
    }
  }

  @override
  Stream<Voter> get voterChanges {
    return _sharedVoterChanges;
  }

  @override
  void disposeRealtime() {
    _remoteDatasource.disposeRealtime();
  }

  @override
  Future<Either<Failure, void>> saveVoterCandidates({
    required String voterSymbol,
    required List<int> candidateIds,
  }) async {
    try {
      if (candidateIds.length > 5) {
        return const Left(
          ServerFailure(message: 'يجب اختيار 5 مرشحين كحد أقصى'),
        );
      }
      await _remoteDatasource.saveVoterCandidates(
        voterSymbol: voterSymbol,
        candidateIds: candidateIds,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في حفظ المرشحين: $e'));
    }
  }

  @override
  Future<Either<Failure, List<int>>> getVoterCandidates(
    String voterSymbol,
  ) async {
    try {
      final ids = await _remoteDatasource.getVoterCandidates(voterSymbol);
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب المرشحين: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, Map<int, int>>>> getListAndCandidateVotes() async {
    try {
      if (await _connectivity.hasInternet) {
        final result = await _remoteDatasource.getListAndCandidateVotes();
        return Right(result);
      } else {
        // Fallback to local cache for lists if offline
        final cachedVoters = await _localDatasource.getCachedVoters(pageSize: 0); // Need to get all or count them
        final Map<int, int> listVotes = {};
        for (final voter in cachedVoters) {
          if (voter.status == AppConstants.statusVoted && voter.listId != null) {
            listVotes[voter.listId!] = (listVotes[voter.listId!] ?? 0) + 1;
          }
        }
        return Right({
          'listVotes': listVotes,
          'candidateVotes': <int, int>{}, // Offline candidate votes aren't fully supported since they are in a different remote table
        });
      }
    } catch (e) {
      return Left(ServerFailure(message: 'خطأ في جلب إحصائيات القوائم والمرشحين: $e'));
    }
  }
}

