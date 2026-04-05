/// Base exception class.
abstract class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException({required this.message, this.statusCode});

  @override
  String toString() => 'AppException: $message (code: $statusCode)';
}

/// Thrown when a Supabase API call fails.
class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode});
}

/// Thrown when authentication fails.
class AuthException extends AppException {
  const AuthException({required super.message, super.statusCode});
}

/// Thrown when local cache operations fail.
class CacheException extends AppException {
  const CacheException({required super.message});
}
