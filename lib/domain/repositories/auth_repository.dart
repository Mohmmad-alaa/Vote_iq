import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/agent.dart';

/// Authentication repository contract.
abstract class AuthRepository {
  /// Sign in with username and password.
  /// Email is constructed as: "$username@app.local".
  Future<Either<Failure, Agent>> signIn({
    required String username,
    required String password,
  });

  /// Sign out the current user.
  Future<Either<Failure, void>> signOut();

  /// Get currently authenticated agent, or null if not logged in.
  Future<Either<Failure, Agent?>> getCurrentAgent();

  /// Check if user is currently authenticated.
  Future<bool> isAuthenticated();
}
