import 'package:equatable/equatable.dart';

/// Base failure class for error handling across the app.
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Server-side failure (Supabase errors).
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

/// Authentication failure.
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode});
}

/// Local cache failure (Hive errors).
class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

/// Network failure (no connectivity).
class NetworkFailure extends Failure {
  const NetworkFailure()
      : super(message: 'لا يوجد اتصال بالإنترنت. يتم العمل بوضع عدم الاتصال.');
}

/// Sync failure.
class SyncFailure extends Failure {
  const SyncFailure({required super.message});
}

/// Permission denied failure (RLS violation).
class PermissionFailure extends Failure {
  const PermissionFailure()
      : super(message: 'ليس لديك صلاحية للوصول إلى هذه البيانات.');
}
