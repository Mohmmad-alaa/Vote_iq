import 'package:flutter_bloc/flutter_bloc.dart';

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
      (_) => loadAll(),
    );
  }

  Future<void> deleteFamily(int id) async {
    final result = await _deleteFamily(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> addSubClan(int familyId, String name) async {
    final result = await _addSubClan(familyId, name);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> deleteSubClan(int id) async {
    final result = await _deleteSubClan(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> addVotingCenter(String name) async {
    final result = await _addVotingCenter(name);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> deleteVotingCenter(int id) async {
    final result = await _deleteVotingCenter(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> addElectoralList(String name) async {
    final result = await _addElectoralList(name);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> deleteElectoralList(int id) async {
    final result = await _deleteElectoralList(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> addCandidate(String name, {int? listId}) async {
    final result = await _addCandidate(name, listId: listId);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
    );
  }

  Future<void> deleteCandidate(int id) async {
    final result = await _deleteCandidate(id);
    result.fold(
      (failure) => emit(LookupError(failure.message)),
      (_) => loadAll(),
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
