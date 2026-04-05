import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/voter.dart';
import '../../repositories/voter_repository.dart';

/// Use case: Update a voter's status (voted / refused / not voted).
class UpdateVoterStatusUseCase {
  final VoterRepository _repository;

  UpdateVoterStatusUseCase(this._repository);

  Future<Either<Failure, Voter>> call({
    required String voterSymbol,
    required String newStatus,
    String? refusalReason,
    int? listId,
    int? candidateId,
  }) {
    return _repository.updateVoterStatus(
      voterSymbol: voterSymbol,
      newStatus: newStatus,
      refusalReason: refusalReason,
      listId: listId,
      candidateId: candidateId,
    );
  }
}
