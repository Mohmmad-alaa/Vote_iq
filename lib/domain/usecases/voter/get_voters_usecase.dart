import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/voter.dart';
import '../../repositories/voter_repository.dart';

/// Use case: Get paginated and filtered list of voters.
class GetVotersUseCase {
  final VoterRepository _repository;

  GetVotersUseCase(this._repository);

  Future<Either<Failure, List<Voter>>> call(
    VoterFilter filter, {
    bool forceRefresh = false,
  }) {
    return _repository.getVoters(filter, forceRefresh: forceRefresh);
  }
}
