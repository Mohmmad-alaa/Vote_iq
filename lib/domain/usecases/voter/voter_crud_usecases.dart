import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/voter.dart';
import '../../repositories/voter_repository.dart';

class CreateVoterUseCase {
  final VoterRepository repository;
  CreateVoterUseCase(this.repository);

  Future<Either<Failure, Voter>> call(Voter voter) {
    return repository.createVoter(voter);
  }
}

class UpdateVoterUseCase {
  final VoterRepository repository;
  UpdateVoterUseCase(this.repository);

  Future<Either<Failure, Voter>> call(Voter voter) {
    return repository.updateVoter(voter);
  }
}

class DeleteVoterUseCase {
  final VoterRepository repository;
  DeleteVoterUseCase(this.repository);

  Future<Either<Failure, void>> call(String voterSymbol) {
    return repository.deleteVoter(voterSymbol);
  }
}

class ImportVotersUseCase {
  final VoterRepository repository;
  ImportVotersUseCase(this.repository);

  Future<Either<Failure, int>> call(String filePath) {
    return repository.importVoters(filePath);
  }
}
