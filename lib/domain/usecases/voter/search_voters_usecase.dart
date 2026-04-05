import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/voter.dart';
import '../../repositories/voter_repository.dart';

/// Use case: Search voters by name using pg_trgm similarity search.
class SearchVotersUseCase {
  final VoterRepository _repository;

  SearchVotersUseCase(this._repository);

  Future<Either<Failure, List<Voter>>> call(String query) {
    return _repository.searchVoters(query);
  }
}
