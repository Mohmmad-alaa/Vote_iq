import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/family.dart';
import '../../../domain/entities/sub_clan.dart';
import '../../../domain/entities/voter.dart';
import '../../../domain/repositories/lookup_repository.dart';
import '../../../domain/repositories/voter_repository.dart';
import '../../../domain/usecases/voter/get_voter_stats_usecase.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final GetVoterStatsUseCase _getVoterStatsUseCase;
  final LookupRepository _lookupRepository;
  final VoterRepository _voterRepository;
  StreamSubscription<Voter>? _realtimeSubscription;
  Timer? _refreshDebounce;
  bool _isRefreshing = false;

  DashboardCubit({
    required GetVoterStatsUseCase getVoterStatsUseCase,
    required LookupRepository lookupRepository,
    required VoterRepository voterRepository,
  }) : _getVoterStatsUseCase = getVoterStatsUseCase,
       _lookupRepository = lookupRepository,
       _voterRepository = voterRepository,
       super(const DashboardInitial()) {
    _subscribeToRealtime();
  }

  Future<void> loadStats() async {
    debugPrint('[DashboardCubit] loadStats start');
    emit(const DashboardLoading());

    final overallResult = await _getVoterStatsUseCase();

    overallResult.fold(
      (failure) {
        debugPrint('[DashboardCubit] loadStats failed: ${failure.message}');
        emit(DashboardError(failure.message));
      },
      (overallStats) {
        debugPrint(
          '[DashboardCubit] loadStats success: '
          'total=${overallStats.total}, voted=${overallStats.voted}, '
          'refused=${overallStats.refused}, notVoted=${overallStats.notVoted}',
        );
        emit(DashboardLoaded(overallStats: overallStats));
      },
    );
  }

  Future<Map<String, VoterStats>> _buildFamilyStats(
    List<Family> families,
  ) async {
    if (families.isEmpty) return {};

    final result = await _voterRepository.getFamilyStatsBatch(
      families.map((family) => family.id).toList(growable: false),
    );

    return result.fold((_) => {}, (statsById) {
      final statsByFamily = <String, VoterStats>{};
      for (final family in families) {
        final stats = statsById[family.id];
        if (stats != null) {
          statsByFamily[family.familyName] = stats;
        }
      }
      return statsByFamily;
    });
  }

  Future<Map<String, VoterStats>> _buildSubClanStats(
    List<SubClan> subClans,
  ) async {
    if (subClans.isEmpty) return {};

    final result = await _voterRepository.getSubClanStatsBatch(
      subClans.map((subClan) => subClan.id).toList(growable: false),
    );

    return result.fold((_) => {}, (statsById) {
      final statsBySubClan = <String, VoterStats>{};
      for (final subClan in subClans) {
        final stats = statsById[subClan.id];
        if (stats != null) {
          statsBySubClan[subClan.subName] = stats;
        }
      }
      return statsBySubClan;
    });
  }

  Future<void> loadFamilyStats() async {
    final currentState = state;
    if (currentState is! DashboardLoaded ||
        currentState.isLoadingFamilyStats ||
        currentState.hasLoadedFamilyStats) {
      return;
    }

    debugPrint('[DashboardCubit] loadFamilyStats start');
    emit(currentState.copyWith(isLoadingFamilyStats: true));

    final familiesResult = await _lookupRepository.getFamilies();

    await familiesResult.fold(
      (_) async {
        debugPrint('[DashboardCubit] loadFamilyStats failed');
        emit(
          currentState.copyWith(
            isLoadingFamilyStats: false,
            hasLoadedFamilyStats: false,
          ),
        );
      },
      (families) async {
        final statsByFamily = await _buildFamilyStats(families);
        debugPrint(
          '[DashboardCubit] loadFamilyStats success: '
          'families=${families.length}, stats=${statsByFamily.length}',
        );
        emit(
          currentState.copyWith(
            isLoadingFamilyStats: false,
            hasLoadedFamilyStats: true,
            statsByFamily: statsByFamily,
          ),
        );
      },
    );
  }

  Future<void> loadSubClanStats() async {
    final currentState = state;
    if (currentState is! DashboardLoaded ||
        currentState.isLoadingSubClanStats ||
        currentState.hasLoadedSubClanStats) {
      return;
    }

    debugPrint('[DashboardCubit] loadSubClanStats start');
    emit(currentState.copyWith(isLoadingSubClanStats: true));

    final subClansResult = await _lookupRepository.getSubClans();

    await subClansResult.fold(
      (_) async {
        debugPrint('[DashboardCubit] loadSubClanStats failed');
        emit(
          currentState.copyWith(
            isLoadingSubClanStats: false,
            hasLoadedSubClanStats: false,
          ),
        );
      },
      (subClans) async {
        final statsBySubClan = await _buildSubClanStats(subClans);
        debugPrint(
          '[DashboardCubit] loadSubClanStats success: '
          'subClans=${subClans.length}, stats=${statsBySubClan.length}',
        );
        emit(
          currentState.copyWith(
            isLoadingSubClanStats: false,
            hasLoadedSubClanStats: true,
            statsBySubClan: statsBySubClan,
          ),
        );
      },
    );
  }

  Future<void> loadListStats() async {
    final currentState = state;
    if (currentState is! DashboardLoaded ||
        currentState.isLoadingListStats ||
        currentState.hasLoadedListStats) {
      return;
    }

    debugPrint('[DashboardCubit] loadListStats start');
    emit(currentState.copyWith(isLoadingListStats: true));

    final listsResult = await _lookupRepository.getLists();
    final candidatesResult = await _lookupRepository.getCandidates();
    final votesResult = await _voterRepository.getListAndCandidateVotes();

    String? failureMsg;
    listsResult.leftMap((f) => failureMsg = f.message);
    candidatesResult.leftMap((f) => failureMsg = f.message);
    votesResult.leftMap((f) => failureMsg = f.message);

    if (failureMsg != null) {
      debugPrint('[DashboardCubit] loadListStats failed: $failureMsg');
      emit(
        currentState.copyWith(
          isLoadingListStats: false,
          hasLoadedListStats: false,
        ),
      );
      return;
    }

    final electoralLists = listsResult.getOrElse(() => []);
    final allCandidates = candidatesResult.getOrElse(() => []);
    final votesMap = votesResult.getOrElse(
      () => {'listVotes': {}, 'candidateVotes': {}},
    );

    final listVotes = votesMap['listVotes'] ?? {};
    final candidateVotes = votesMap['candidateVotes'] ?? {};

    final listStats = <ListStatItem>[];

    for (final list in electoralLists) {
      final listCandidates = allCandidates
          .where((c) => c.listId == list.id)
          .toList();

      final candidateStatItems = <CandidateStatItem>[];
      for (final candidate in listCandidates) {
        final votes = candidateVotes[candidate.id] ?? 0;
        if (votes > 0) {
          candidateStatItems.add(
            CandidateStatItem(
              candidateName: candidate.candidateName,
              votes: votes,
            ),
          );
        }
      }

      // Sort candidates by numerical order extracted from name
      candidateStatItems.sort((a, b) {
        int extractNumber(String name) {
          final match = RegExp(r'\d+').firstMatch(name);
          return match != null ? int.parse(match.group(0)!) : 999999;
        }

        int numA = extractNumber(a.candidateName);
        int numB = extractNumber(b.candidateName);
        if (numA != numB) {
          return numA.compareTo(numB);
        }
        return b.votes.compareTo(a.votes); // fallback sort by highest votes
      });

      listStats.add(
        ListStatItem(
          listName: list.listName,
          totalVotes: listVotes[list.id] ?? 0,
          candidates: candidateStatItems,
        ),
      );
    }

    // Sort lists by highest total votes
    listStats.sort((a, b) => b.totalVotes.compareTo(a.totalVotes));

    debugPrint(
      '[DashboardCubit] loadListStats success: lists=${listStats.length}',
    );
    emit(
      currentState.copyWith(
        isLoadingListStats: false,
        hasLoadedListStats: true,
        statsByList: listStats,
      ),
    );
  }

  Future<void> refreshStats() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final currentState = state;
    final overallResult = await _getVoterStatsUseCase();

    try {
      await overallResult.fold((failure) async {}, (overallStats) async {
        if (currentState is DashboardLoaded) {
          // Emit overall stats immediately (from local cache — fast)
          var nextState = currentState.copyWith(overallStats: overallStats);
          emit(nextState);

          // Refresh detailed stats only if still needed (not superseded by another refresh)
          if (_isRefreshing && currentState.hasLoadedFamilyStats) {
            final familiesResult = await _lookupRepository.getFamilies();
            final refreshedFamilyStats = await familiesResult.fold(
              (_) async => currentState.statsByFamily ?? <String, VoterStats>{},
              _buildFamilyStats,
            );
            nextState = nextState.copyWith(
              isLoadingFamilyStats: false,
              hasLoadedFamilyStats: true,
              statsByFamily: refreshedFamilyStats,
            );
            emit(nextState);
          }

          if (_isRefreshing && currentState.hasLoadedSubClanStats) {
            final subClansResult = await _lookupRepository.getSubClans();
            final refreshedSubClanStats = await subClansResult.fold(
              (_) async =>
                  currentState.statsBySubClan ?? <String, VoterStats>{},
              _buildSubClanStats,
            );
            nextState = nextState.copyWith(
              isLoadingSubClanStats: false,
              hasLoadedSubClanStats: true,
              statsBySubClan: refreshedSubClanStats,
            );
            emit(nextState);
          }

          if (_isRefreshing && currentState.hasLoadedListStats) {
            final listsResult = await _lookupRepository.getLists();
            final candidatesResult = await _lookupRepository.getCandidates();
            final votesResult = await _voterRepository
                .getListAndCandidateVotes();

            if (listsResult.isRight() &&
                candidatesResult.isRight() &&
                votesResult.isRight()) {
              final electoralLists = listsResult.getOrElse(() => []);
              final allCandidates = candidatesResult.getOrElse(() => []);
              final votesMap = votesResult.getOrElse(
                () => {'listVotes': {}, 'candidateVotes': {}},
              );

              final listVotes = votesMap['listVotes'] ?? {};
              final candidateVotes = votesMap['candidateVotes'] ?? {};

              final listStats = <ListStatItem>[];

              for (final list in electoralLists) {
                final listCandidates = allCandidates
                    .where((c) => c.listId == list.id)
                    .toList();

                final candidateStatItems = <CandidateStatItem>[];
                for (final candidate in listCandidates) {
                  final votes = candidateVotes[candidate.id] ?? 0;
                  if (votes > 0) {
                    candidateStatItems.add(
                      CandidateStatItem(
                        candidateName: candidate.candidateName,
                        votes: votes,
                      ),
                    );
                  }
                }

                candidateStatItems.sort((a, b) {
                  int extractNumber(String name) {
                    final match = RegExp(r'\d+').firstMatch(name);
                    return match != null ? int.parse(match.group(0)!) : 999999;
                  }

                  int numA = extractNumber(a.candidateName);
                  int numB = extractNumber(b.candidateName);
                  if (numA != numB) {
                    return numA.compareTo(numB);
                  }
                  return b.votes.compareTo(a.votes);
                });

                listStats.add(
                  ListStatItem(
                    listName: list.listName,
                    totalVotes: listVotes[list.id] ?? 0,
                    candidates: candidateStatItems,
                  ),
                );
              }

              listStats.sort((a, b) => b.totalVotes.compareTo(a.totalVotes));

              nextState = nextState.copyWith(
                isLoadingListStats: false,
                hasLoadedListStats: true,
                statsByList: listStats,
              );
              emit(nextState);
            } else {
              emit(nextState.copyWith(isLoadingListStats: false));
            }
          }
        } else {
          emit(DashboardLoaded(overallStats: overallStats));
        }
      });
    } finally {
      _isRefreshing = false;
    }
  }

  void _subscribeToRealtime() {
    _realtimeSubscription = _voterRepository.voterChanges.listen((
      updatedVoter,
    ) {
      debugPrint(
        '[DashboardCubit] realtime update received: '
        'voterSymbol=${updatedVoter.voterSymbol}, status=${updatedVoter.status}',
      );
      _scheduleRealtimeRefresh();
    });
  }

  void _scheduleRealtimeRefresh() {
    if (state is! DashboardLoaded) return;

    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 2000), () {
      debugPrint('[DashboardCubit] refreshing stats after realtime update');
      refreshStats();
    });
  }

  @override
  Future<void> close() {
    _refreshDebounce?.cancel();
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
