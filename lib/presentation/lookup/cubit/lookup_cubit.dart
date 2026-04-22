import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/electoral_list.dart';
import '../../../domain/entities/family.dart';
import '../../../domain/entities/sub_clan.dart';
import '../../../domain/entities/voting_center.dart';
import '../../../domain/repositories/lookup_repository.dart';
import '../../../domain/usecases/lookup/lookup_crud_usecases.dart';
import '../../../domain/usecases/lookup/import_lists_candidates_usecase.dart';
import 'lookup_state.dart';

class LookupCubit extends Cubit<LookupState> {
  final LookupRepository _lookupRepository;
  final AddFamilyUseCase _addFamily;
  final DeleteFamilyUseCase _deleteFamily;
  final AddSubClanUseCase _addSubClan;
  final DeleteSubClanUseCase _deleteSubClan;
  final AddVotingCenterUseCase _addVotingCenter;
  final DeleteVotingCenterUseCase _deleteVotingCenter;
  final AddElectoralListUseCase _addElectoralList;
  final DeleteElectoralListUseCase _deleteElectoralList;
  final AddCandidateUseCase _addCandidate;
  final DeleteCandidateUseCase _deleteCandidate;
  final ImportListsCandidatesUseCase _importListsCandidates;

  LookupCubit({
    required LookupRepository lookupRepository,
    required AddFamilyUseCase addFamily,
    required DeleteFamilyUseCase deleteFamily,
    required AddSubClanUseCase addSubClan,
    required DeleteSubClanUseCase deleteSubClan,
    required AddVotingCenterUseCase addVotingCenter,
    required DeleteVotingCenterUseCase deleteVotingCenter,
    required AddElectoralListUseCase addElectoralList,
    required DeleteElectoralListUseCase deleteElectoralList,
    required AddCandidateUseCase addCandidate,
    required DeleteCandidateUseCase deleteCandidate,
    required ImportListsCandidatesUseCase importListsCandidates,
  })  : _lookupRepository = lookupRepository,
        _addFamily = addFamily,
        _deleteFamily = deleteFamily,
        _addSubClan = addSubClan,
        _deleteSubClan = deleteSubClan,
        _addVotingCenter = addVotingCenter,
        _deleteVotingCenter = deleteVotingCenter,
        _addElectoralList = addElectoralList,
        _deleteElectoralList = deleteElectoralList,
        _addCandidate = addCandidate,
        _deleteCandidate = deleteCandidate,
        _importListsCandidates = importListsCandidates,
        super(const LookupInitial());

  List<Family> _sortedFamilies(List<Family> families) {
    final sorted = List<Family>.from(families);
    sorted.sort((a, b) => a.familyName.compareTo(b.familyName));
    return sorted;
  }

  List<SubClan> _sortedSubClans(List<SubClan> subClans) {
    final sorted = List<SubClan>.from(subClans);
    sorted.sort((a, b) {
      final familyCompare = (a.familyName ?? '').compareTo(b.familyName ?? '');
      if (familyCompare != 0) {
        return familyCompare;
      }
      return a.subName.compareTo(b.subName);
    });
    return sorted;
  }

  List<VotingCenter> _sortedCenters(List<VotingCenter> centers) {
    final sorted = List<VotingCenter>.from(centers);
    sorted.sort((a, b) => a.centerName.compareTo(b.centerName));
    return sorted;
  }

  List<ElectoralList> _sortedLists(List<ElectoralList> lists) {
    final sorted = List<ElectoralList>.from(lists);
    sorted.sort((a, b) => a.listName.compareTo(b.listName));
    return sorted;
  }

  List<Candidate> _sortedCandidates(List<Candidate> candidates) {
    final sorted = List<Candidate>.from(candidates);
    sorted.sort((a, b) => a.candidateName.compareTo(b.candidateName));
    return sorted;
  }

  Future<void> loadAll() async {
    emit(const LookupLoading());

    final results = await Future.wait([
      _lookupRepository.getFamilies(),
      _lookupRepository.getSubClans(),
      _lookupRepository.getVotingCenters(),
      _lookupRepository.getLists(),
      _lookupRepository.getCandidates(),
    ]);

    final familiesResult = results[0] as dynamic;
    final subClansResult = results[1] as dynamic;
    final centersResult = results[2] as dynamic;
    final listsResult = results[3] as dynamic;
    final candidatesResult = results[4] as dynamic;

    familiesResult.fold(
      (failure) => emit(LookupError(failure.message)),
      (families) {
        subClansResult.fold(
          (failure) => emit(LookupError(failure.message)),
          (subClans) {
            centersResult.fold(
              (failure) => emit(LookupError(failure.message)),
              (centers) {
                listsResult.fold(
                  (failure) => emit(LookupError(failure.message)),
                  (electoralLists) {
                    candidatesResult.fold(
                      (failure) => emit(LookupError(failure.message)),
                      (candidates) {
                        emit(
                          LookupLoaded(
                            families: families,
                            subClans: subClans,
                            centers: centers,
                            electoralLists: electoralLists,
                            candidates: candidates,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> addFamily(String name) async {
    final result = await _addFamily(name);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (family) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            families: _sortedFamilies([...currentState.families, family]),
          ),
        );
      },
    );
  }

  Future<void> deleteFamily(int id) async {
    final result = await _deleteFamily(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            families: currentState.families.where((item) => item.id != id).toList(),
            subClans: currentState.subClans
                .where((item) => item.familyId != id)
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> addSubClan(int familyId, String name) async {
    final result = await _addSubClan(familyId, name);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (subClan) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            subClans: _sortedSubClans([...currentState.subClans, subClan]),
          ),
        );
      },
    );
  }

  Future<void> deleteSubClan(int id) async {
    final result = await _deleteSubClan(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            subClans: currentState.subClans
                .where((item) => item.id != id)
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> addVotingCenter(String name) async {
    final result = await _addVotingCenter(name);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (center) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            centers: _sortedCenters([...currentState.centers, center]),
          ),
        );
      },
    );
  }

  Future<void> deleteVotingCenter(int id) async {
    final result = await _deleteVotingCenter(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            centers: currentState.centers.where((item) => item.id != id).toList(),
          ),
        );
      },
    );
  }

  Future<void> addElectoralList(String name) async {
    final result = await _addElectoralList(name);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (electoralList) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            electoralLists: _sortedLists([
              ...currentState.electoralLists,
              electoralList,
            ]),
          ),
        );
      },
    );
  }

  Future<void> deleteElectoralList(int id) async {
    final result = await _deleteElectoralList(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            electoralLists: currentState.electoralLists
                .where((item) => item.id != id)
                .toList(),
            candidates: currentState.candidates
                .where((item) => item.listId != id)
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> addCandidate(String name, {int? listId}) async {
    final result = await _addCandidate(name, listId: listId);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (candidate) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            candidates: _sortedCandidates([...currentState.candidates, candidate]),
          ),
        );
      },
    );
  }

  Future<void> deleteCandidate(int id) async {
    final result = await _deleteCandidate(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) {
        final currentState = state;
        if (currentState is! LookupLoaded) {
          loadAll();
          return;
        }

        emit(
          currentState.copyWith(
            candidates: currentState.candidates
                .where((item) => item.id != id)
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> importListsAndCandidates(String filePath) async {
    emit(const LookupLoading());
    final result = await _importListsCandidates(filePath);
    result.fold(
      (failure) => emit(LookupError(failure.message ?? 'Unknown error')),
      (_) => loadAll(),
    );
  }
}
