import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/candidate.dart';
import '../../entities/electoral_list.dart';
import '../../entities/family.dart';
import '../../entities/sub_clan.dart';
import '../../entities/voting_center.dart';
import '../../repositories/lookup_repository.dart';

class AddFamilyUseCase {
  final LookupRepository repository;
  AddFamilyUseCase(this.repository);

  Future<Either<Failure, Family>> call(String name) {
    return repository.addFamily(name);
  }
}

class DeleteFamilyUseCase {
  final LookupRepository repository;
  DeleteFamilyUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) {
    return repository.deleteFamily(id);
  }
}

class AddSubClanUseCase {
  final LookupRepository repository;
  AddSubClanUseCase(this.repository);

  Future<Either<Failure, SubClan>> call(int familyId, String name) {
    return repository.addSubClan(familyId, name);
  }
}

class DeleteSubClanUseCase {
  final LookupRepository repository;
  DeleteSubClanUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) {
    return repository.deleteSubClan(id);
  }
}

class AddVotingCenterUseCase {
  final LookupRepository repository;
  AddVotingCenterUseCase(this.repository);

  Future<Either<Failure, VotingCenter>> call(String name) {
    return repository.addVotingCenter(name);
  }
}

class DeleteVotingCenterUseCase {
  final LookupRepository repository;
  DeleteVotingCenterUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) {
    return repository.deleteVotingCenter(id);
  }
}

class AddElectoralListUseCase {
  final LookupRepository repository;
  AddElectoralListUseCase(this.repository);

  Future<Either<Failure, ElectoralList>> call(String name) {
    return repository.addElectoralList(name);
  }
}

class DeleteElectoralListUseCase {
  final LookupRepository repository;
  DeleteElectoralListUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) {
    return repository.deleteElectoralList(id);
  }
}

class AddCandidateUseCase {
  final LookupRepository repository;
  AddCandidateUseCase(this.repository);

  Future<Either<Failure, Candidate>> call(String name, {int? listId}) {
    return repository.addCandidate(name, listId: listId);
  }
}

class DeleteCandidateUseCase {
  final LookupRepository repository;
  DeleteCandidateUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) {
    return repository.deleteCandidate(id);
  }
}
