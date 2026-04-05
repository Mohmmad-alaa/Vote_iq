import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

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
       super(const VotersInitial());

  Future<void> _loadFilteredVoters({
    List<int>? familyIds,
    int? subClanId,
    int? centerId,
    String? status,
    Object? searchQuery = _keepCurrentSearch,
    bool forceRefresh = false,
    bool silentRefresh = false,
  }) async {
    final currentState = state is VotersLoaded ? state as VotersLoaded : null;
    final effectiveSearchQuery = searchQuery == _keepCurrentSearch
        ? currentState?.searchQuery
        : (searchQuery as String?)?.trim();

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
      pageSize: 0,
    );

    final result = await _getVotersUseCase(filter, forceRefresh: forceRefresh);

    result.fold(
      (failure) {
        debugPrint('[VotersCubit] load failed: ${failure.message}');
        if (!silentRefresh) {
          emit(VotersError(failure.message));
        }
      },
      (voters) {
        debugPrint(
          '[VotersCubit] load success: count=${voters.length}, '
          'familyIds=$familyIds, subClanId=$subClanId, centerId=$centerId, '
          'status=$status, searchQuery=${filter.searchQuery}',
        );
        emit(
          VotersLoaded(
            voters: voters,
            hasReachedEnd: true,
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

  /// Infinite scroll is no longer needed because the full register is loaded.
  Future<void> loadMore() async {}

  /// Search inside the full local register while preserving active filters.
  Future<void> searchVoters(String query) async {
    final currentState = state is VotersLoaded ? state as VotersLoaded : null;

    await _loadFilteredVoters(
      familyIds: currentState?.filterFamilyIds,
      subClanId: currentState?.filterSubClanId,
      centerId: currentState?.filterCenterId,
      status: currentState?.filterStatus,
      searchQuery: query,
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
  Future<void> updateVoter(Voter voter) async {
    final result = await _updateVoterUseCase(voter);
    await result.fold(
      (f) async => emit(VotersError(f.message)),
      (_) => _reloadCurrentView(),
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
        print('DEBUG: VotersCubit: Import FAILED: ' + f.message);
        emit(VotersError(f.message));
      },
      (count) {
        print(
          'DEBUG: VotersCubit: Import SUCCESS. Imported ' +
              count.toString() +
              ' voters.',
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
    final existingIndex = updatedList.indexWhere(
      (v) => v.voterSymbol == updatedVoter.voterSymbol,
    );
    final matchesCurrentView = _matchesCurrentView(updatedVoter, currentState);

    if (existingIndex >= 0) {
      if (matchesCurrentView) {
        updatedList[existingIndex] = updatedVoter;
      } else {
        updatedList.removeAt(existingIndex);
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
    } else {
      return;
    }

    emit(currentState.copyWith(voters: updatedList));
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
    _voterRepository.disposeRealtime();
    return super.close();
  }
}
