import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/agent.dart';
import '../../repositories/auth_repository.dart';

/// Use case: Sign in with username and password.
class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Either<Failure, Agent>> call({
    required String username,
    required String password,
  }) {
    return _repository.signIn(username: username, password: password);
  }
}
