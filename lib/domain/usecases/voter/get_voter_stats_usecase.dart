import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/voter_repository.dart';

/// Use case: Get voting statistics.
class GetVoterStatsUseCase {
  final VoterRepository _repository;

  GetVoterStatsUseCase(this._repository);

  Future<Either<Failure, VoterStats>> call({
    int? familyId,
    int? subClanId,
    int? centerId,
  }) {
    return _repository.getVoterStats(
      familyId: familyId,
      subClanId: subClanId,
      centerId: centerId,
    );
  }
}
