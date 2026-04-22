import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/voter_repository.dart';

/// Use case: Sign out the current user.
class LogoutUseCase {
  final AuthRepository _repository;
  final VoterRepository _voterRepository;

  LogoutUseCase(this._repository, this._voterRepository);

  Future<Either<Failure, void>> call() async {
    await _voterRepository.clearCache();
    return _repository.signOut();
  }
}
