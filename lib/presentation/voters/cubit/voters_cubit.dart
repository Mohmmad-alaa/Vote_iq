import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/voter.dart';
import '../../../domain/repositories/voter_repository.dart';
import '../../../domain/usecases/voter/get_voters_usecase.dart';
import '../../../domain/usecases/voter/search_voters_usecase.dart';
import '../../../domain/usecases/voter/update_voter_status_usecase.dart';
import '../../../domain/usecases/voter/voter_crud_usecases.dart';
import 'voters_state.dart';

/// Voters cubit manages voter list, search, filter, and status updates.
class VotersCubit extends Cubit<VotersState> {
  static const Object _keepCurrentSearch = Object();

  final GetVotersUseCase _getVotersUseCase;
  final SearchVotersUseCase _searchVotersUseCase;
  final UpdateVoterStatusUseCase _updateVoterStatusUseCase;
  final CreateVoterUseCase _createVoterUseCase;
  final UpdateVoterUseCase _updateVoterUseCase;
  final DeleteVoterUseCase _deleteVoterUseCase;
  final ImportVotersUseCase _importVotersUseCase;
  final VoterRepository _voterRepository;

  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _syncSubscription;
  int _currentPage = 0;
  bool _isLoadingMore = false;

  static final RegExp _searchSanitizer = RegExp(r'[^\w\s\u0600-\u06FF]');

  VotersCubit({
    required GetVotersUseCase getVotersUseCase,
    required SearchVotersUseCase searchVotersUseCase,
    required UpdateVoterStatusUseCase updateVoterStatusUseCase,
    required CreateVoterUseCase createVoterUseCase,
    required UpdateVoterUseCase updateVoterUseCase,
    required DeleteVoterUseCase deleteVoterUseCase,
    required ImportVotersUseCase importVotersUseCase,
    required VoterRepository voterRepository,
  }) : _getVotersUseCase = getVotersUseCase,
       _searchVotersUseCase = searchVotersUseCase,
       _updateVoterStatusUseCase = updateVoterStatusUseCase,
       _createVoterUseCase = createVoterUseCase,
       _updateVoterUseCase = updateVoterUseCase,
       _deleteVoterUseCase = deleteVoterUseCase,
       _importVotersUseCase = importVotersUseCase,
       _voterRepository = voterRepository,
       super(const VotersInitial()) {
    _syncSubscription = _voterRepository.onFullSyncComplete.listen((_) {
      if (!isClosed) {
        refreshCurrentView(forceRefresh: false, restartRealtime: false);
      }
    });
  }

  Future<void> _loadFilteredVoters({
    List<int>? familyIds,
    int? subClanId,
    int? centerId,
    String? status,
    Object? searchQuery = _keepCurrentSearch,
    bool forceRefresh = false,
    bool silentRefresh = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final currentState = state is VotersLoaded ? state as VotersLoaded : null;
    final effectiveSearchQuery = searchQuery == _keepCurrentSearch
        ? currentState?.searchQuery
        : (searchQuery as String?)?.trim();
    const pageSize = AppConstants.pageSize;

    if (!silentRefresh) {
      emit(const VotersLoading());
    }

    final filter = VoterFilter(
      familyIds: familyIds,
      subClanId: subClanId,
      centerId: centerId,
      status: status,
      searchQuery: effectiveSearchQuery == null || effectiveSearchQuery.isEmpty
          ? null
          : effectiveSearchQuery,
      page: 0,
      pageSize: pageSize,
    );

    final resultFuture = _getVotersUseCase(filter, forceRefresh: forceRefresh);
    final countFuture = _voterRepository.countVoters(filter);
    final result = await resultFuture;
    final countResult = await countFuture;
    final totalCount = countResult.fold((_) => 0, (count) => count);

    result.fold(
      (failure) {
        debugPrint(
          '[VotersCubit] load failed after ${stopwatch.elapsedMilliseconds}ms: '
          '${failure.message}',
        );
        debugPrint('[VotersCubit] load failed: ${failure.message}');
        if (!silentRefresh) {
          emit(VotersError(failure.message));
        }
      },
      (voters) {
        _currentPage = 0;
        _isLoadingMore = false;
        debugPrint(
          '[VotersCubit] load success: count=${voters.length}, '
          'familyIds=$familyIds, subClanId=$subClanId, centerId=$centerId, '
          'status=$status, searchQuery=${filter.searchQuery}, '
          'durationMs=${stopwatch.elapsedMilliseconds}',
        );
        emit(
          VotersLoaded(
            voters: voters,
            totalCount: totalCount > 0 ? totalCount : voters.length,
            hasReachedEnd: voters.length < pageSize,
            filterFamilyIds: familyIds,
            filterSubClanId: subClanId,
            filterCenterId: centerId,
            filterStatus: status,
            searchQuery: filter.searchQuery,
          ),
        );
      },
    );
  }

  /// Load the full voter register with optional filters.
  Future<void> loadVoters({
    List<int>? familyIds,
    int? subClanId,
    int? centerId,
    String? status,
    bool forceRefresh = false,
  }) {
    return _loadFilteredVoters(
      familyIds: familyIds,
      subClanId: subClanId,
      centerId: centerId,
      status: status,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! VotersLoaded ||
        currentState.hasReachedEnd ||
        currentState.isLoadingMore ||
        _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));
    final stopwatch = Stopwatch()..start();
    final nextPage = _currentPage + 1;

    final filter = VoterFilter(
      familyIds: currentState.filterFamilyIds,
      subClanId: currentState.filterSubClanId,
      centerId: currentState.filterCenterId,
      status: currentState.filterStatus,
      searchQuery: currentState.searchQuery,
      page: nextPage,
      pageSize: AppConstants.pageSize,
    );

    final result = await _getVotersUseCase(filter);
    result.fold(
      (failure) {
        _isLoadingMore = false;
        debugPrint(
          '[VotersCubit] loadMore failed after ${stopwatch.elapsedMilliseconds}ms: '
          '${failure.message}',
        );
        if (!isClosed && state is VotersLoaded) {
          emit((state as VotersLoaded).copyWith(isLoadingMore: false));
        }
      },
      (nextPageVoters) {
        _isLoadingMore = false;
        _currentPage = nextPage;

        final merged = <Voter>[...currentState.voters];
        final existingSymbols = currentState.voters
            .map((voter) => voter.voterSymbol)
            .toSet();

        for (final voter in nextPageVoters) {
          if (existingSymbols.add(voter.voterSymbol)) {
            merged.add(voter);
          }
        }

        debugPrint(
          '[VotersCubit] loadMore success: page=$nextPage, '
          'count=${nextPageVoters.length}, total=${merged.length}, '
          'durationMs=${stopwatch.elapsedMilliseconds}',
        );
        emit(
          currentState.copyWith(
            voters: merged,
            totalCount: currentState.totalCount,
            isLoadingMore: false,
            hasReachedEnd: nextPageVoters.length < AppConstants.pageSize,
          ),
        );
      },
    );
  }

  /// Search inside the full local register while preserving active filters.
  /// Uses silentRefresh to avoid showing shimmer — keeps current data visible
  /// while search results update seamlessly.
  Future<void> searchVoters(String query) async {
    final currentState = state is VotersLoaded ? state as VotersLoaded : null;

    await _loadFilteredVoters(
      familyIds: currentState?.filterFamilyIds,
      subClanId: currentState?.filterSubClanId,
      centerId: currentState?.filterCenterId,
      status: currentState?.filterStatus,
      searchQuery: query,
      silentRefresh: currentState != null, // silent only when data is already loaded
    );
  }

  Future<void> _reloadCurrentView() async {
    final currentState = state is VotersLoaded ? state as VotersLoaded : null;

    await _loadFilteredVoters(
      familyIds: currentState?.filterFamilyIds,
      subClanId: currentState?.filterSubClanId,
      centerId: currentState?.filterCenterId,
      status: currentState?.filterStatus,
      searchQuery: currentState?.searchQuery ?? '',
    );
  }

  Future<void> refreshCurrentView({
    bool forceRefresh = true,
    bool restartRealtime = false,
  }) async {
    debugPrint(
      '[VotersCubit] refreshCurrentView start: '
      'forceRefresh=$forceRefresh, restartRealtime=$restartRealtime',
    );

    if (restartRealtime) {
      await _restartRealtimeSubscription();
    }

    final currentState = state is VotersLoaded ? state as VotersLoaded : null;
    await _loadFilteredVoters(
      familyIds: currentState?.filterFamilyIds,
      subClanId: currentState?.filterSubClanId,
      centerId: currentState?.filterCenterId,
      status: currentState?.filterStatus,
      searchQuery: currentState?.searchQuery ?? '',
      forceRefresh: forceRefresh,
      silentRefresh: true, // Prevent loading shimmer from clearing the UI
    );
  }

  /// Reset all voters to 'not voted'
  Future<void> resetAllVoters() async {
    emit(const VotersLoading());
    final result = await _voterRepository.resetAllVoters();
    result.fold(
      (failure) {
        emit(VotersError(failure.message));
        _reloadCurrentView();
      },
      (_) {
        refreshCurrentView(forceRefresh: true);
      },
    );
  }

  /// Update a voter's status.
  Future<Voter?> updateVoterStatus({
    required String voterSymbol,
    required String newStatus,
    String? refusalReason,
    int? listId,
    int? candidateId,
  }) async {
    debugPrint(
      '[VotersCubit] update status start: '
      'voterSymbol=$voterSymbol, newStatus=$newStatus, refusalReason=$refusalReason, '
      'listId=$listId, candidateId=$candidateId',
    );
    final result = await _updateVoterStatusUseCase(
      voterSymbol: voterSymbol,
      newStatus: newStatus,
      refusalReason: refusalReason,
      listId: listId,
      candidateId: candidateId,
    );

    return result.fold(
      (failure) {
        debugPrint(
          '[VotersCubit] update status failed: '
          'voterSymbol=$voterSymbol, message=${failure.message}',
        );
        return null;
      },
      (updatedVoter) {
        debugPrint(
          '[VotersCubit] update status success: '
          'voterSymbol=$voterSymbol, status=${updatedVoter.status}',
        );
        // Update the visible list immediately and rely on the local cache plus
        // realtime sync instead of reloading the full register after every vote.
        _applyRealtimeUpdate(updatedVoter);
        return updatedVoter;
      },
    );
  }

  Future<String?> saveVoterCandidates({
    required String voterSymbol,
    required List<int> candidateIds,
  }) async {
    final result = await _voterRepository.saveVoterCandidates(
      voterSymbol: voterSymbol,
      candidateIds: candidateIds,
    );
    return result.fold((failure) {
      debugPrint(
        '[VotersCubit] saveVoterCandidates failed: '
        'voterSymbol=$voterSymbol, message=${failure.message}',
      );
      return failure.message;
    }, (_) {
      debugPrint(
        '[VotersCubit] saveVoterCandidates success: '
        'voterSymbol=$voterSymbol, count=${candidateIds.length}',
      );
      return null;
    });
  }

  /// Create a new voter.
  Future<void> createVoter(Voter voter) async {
    final result = await _createVoterUseCase(voter);
    await result.fold(
      (f) async => emit(VotersError(f.message)),
      (_) => _reloadCurrentView(),
    );
  }

  /// Update an existing voter's details.
  Future<void> updateVoter(Voter voter, {bool reload = true}) async {
    final result = await _updateVoterUseCase(voter);
    await result.fold(
      (f) async {
        if (reload) emit(VotersError(f.message));
      },
      (_) {
        if (reload) _reloadCurrentView();
      },
    );
  }

  /// Delete a voter.
  Future<void> deleteVoter(String symbol) async {
    final result = await _deleteVoterUseCase(symbol);
    await result.fold(
      (f) async => emit(VotersError(f.message)),
      (_) => _reloadCurrentView(),
    );
  }

  /// Import voters from Excel.
  Future<void> importVoters(String filePath) async {
    print('DEBUG: VotersCubit: importVoters called with path: $filePath');
    emit(const VotersLoading());
    final result = await _importVotersUseCase(filePath);
    result.fold(
      (f) {
        print('DEBUG: VotersCubit: Import FAILED: ${f.message}');
        emit(VotersError(f.message));
      },
      (count) {
        print(
          'DEBUG: VotersCubit: Import SUCCESS. Imported $count voters.',
        );
        loadVoters();
      },
    );
  }

  /// Get all unique family names for filter dropdown.
  Future<List<String>> getAllUniqueFamilies() async {
    final result = await _voterRepository.getAllUniqueFamilies();
    return result.fold((failure) => <String>[], (names) => names);
  }

  /// Get all family name to ID mapping for server-side filtering.
  Future<Map<String, int>> getFamiliesMap() async {
    final result = await _voterRepository.getFamiliesMap();
    return result.fold((failure) => <String, int>{}, (map) => map);
  }

  /// Subscribe to real-time voter changes.
  void subscribeToRealtime() {
    if (_realtimeSubscription != null) {
      return;
    }

    _realtimeSubscription = _voterRepository.voterChanges.listen((
      updatedVoter,
    ) {
      debugPrint(
        '[VotersCubit] realtime update received: '
        'voterSymbol=${updatedVoter.voterSymbol}, status=${updatedVoter.status}',
      );
      _applyRealtimeUpdate(updatedVoter);
    });
  }

  Future<void> _restartRealtimeSubscription() async {
    debugPrint('[VotersCubit] restarting realtime subscription');
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _voterRepository.disposeRealtime();
    subscribeToRealtime();
  }

  void _applyRealtimeUpdate(Voter updatedVoter) {
    final currentState = state;
    if (currentState is! VotersLoaded) return;

    final updatedList = List<Voter>.from(currentState.voters);
    var updatedTotalCount = currentState.totalCount;
    final existingIndex = updatedList.indexWhere(
      (v) => v.voterSymbol == updatedVoter.voterSymbol,
    );
    final matchesCurrentView = _matchesCurrentView(updatedVoter, currentState);

    if (existingIndex >= 0) {
      if (matchesCurrentView) {
        updatedList[existingIndex] = updatedVoter;
      } else {
        updatedList.removeAt(existingIndex);
        if (updatedTotalCount > 0) {
          updatedTotalCount--;
        }
      }
    } else if (matchesCurrentView) {
      // Binary insert to maintain sorted order without full re-sort
      final symbol = updatedVoter.voterSymbol;
      int lo = 0, hi = updatedList.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (updatedList[mid].voterSymbol.compareTo(symbol) < 0) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      updatedList.insert(lo, updatedVoter);
      if (currentState.hasReachedEnd) {
        updatedTotalCount++;
      }
    } else {
      return;
    }

    emit(
      currentState.copyWith(
        voters: updatedList,
        totalCount: updatedTotalCount,
      ),
    );
  }

  bool _matchesCurrentView(Voter voter, VotersLoaded state) {
    if (state.filterFamilyIds != null &&
        state.filterFamilyIds!.isNotEmpty &&
        (voter.familyId == null ||
            !state.filterFamilyIds!.contains(voter.familyId))) {
      return false;
    }

    if (state.filterSubClanId != null &&
        voter.subClanId != state.filterSubClanId) {
      return false;
    }

    if (state.filterCenterId != null &&
        voter.centerId != state.filterCenterId) {
      return false;
    }

    if (state.filterStatus != null && voter.status != state.filterStatus) {
      return false;
    }

    final searchQuery = state.searchQuery?.trim();
    if (searchQuery == null || searchQuery.isEmpty) {
      return true;
    }

    return _matchesSearch(voter, searchQuery);
  }

  bool _matchesSearch(Voter voter, String searchQuery) {
    final cleanQuery = searchQuery
        .replaceAll(_searchSanitizer, '')
        .trim()
        .toLowerCase();
    if (cleanQuery.isEmpty) return true;

    final searchText = [
      voter.voterSymbol,
      voter.firstName,
      voter.fatherName,
      voter.grandfatherName,
      voter.familyName,
    ]
        .whereType<String>()
        .join(' ')
        .replaceAll(_searchSanitizer, '')
        .trim()
        .toLowerCase();

    final terms = cleanQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);

    return terms.every(searchText.contains);
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    _syncSubscription?.cancel();
    _voterRepository.disposeRealtime();
    return super.close();
  }
}
