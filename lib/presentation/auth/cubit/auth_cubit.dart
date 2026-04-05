import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../../domain/usecases/auth/logout_usecase.dart';
import 'auth_state.dart';

/// Auth cubit — manages authentication state.
class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final AuthRepository _authRepository;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required AuthRepository authRepository,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _authRepository = authRepository,
        super(const AuthInitial());

  /// Check if user is already authenticated (app startup).
  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());

    final isAuth = await _authRepository.isAuthenticated();
    if (!isAuth) {
      emit(const AuthUnauthenticated());
      return;
    }

    final result = await _authRepository.getCurrentAgent();
    result.fold(
      (failure) => emit(const AuthUnauthenticated()),
      (agent) {
        if (agent != null) {
          emit(AuthAuthenticated(agent));
        } else {
          emit(const AuthUnauthenticated());
        }
      },
    );
  }

  /// Sign in with username and password.
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    emit(const AuthLoading());

    final result = await _loginUseCase(
      username: username,
      password: password,
    );

    result.fold(
      (failure) {
        print('DEBUG: AuthCubit Login Failure: ${failure.message}');
        emit(AuthError(failure.message));
      },
      (agent) {
        print('DEBUG: AuthCubit Login Success: ${agent.username}');
        emit(AuthAuthenticated(agent));
      },
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    emit(const AuthLoading());

    final result = await _logoutUseCase();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const AuthUnauthenticated()),
    );
  }
}
