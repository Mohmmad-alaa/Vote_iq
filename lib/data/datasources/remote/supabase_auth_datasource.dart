import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/agent_model.dart';

/// Remote datasource for authentication via Supabase Auth.
class SupabaseAuthDatasource {
  final SupabaseClient _client;
  static const String _authCacheBox = 'auth_cache';
  static const String _agentKey = 'current_agent';

  SupabaseAuthDatasource(this._client);

  /// Sign in using username + password.
  /// Email is constructed as: "$username@app.local".
  Future<AgentModel> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final normalizedUsername = AppConstants.normalizeUsername(username);
      final candidateEmails = <String>[
        AppConstants.buildAgentEmail(normalizedUsername),
      ];
      for (final suffix in AppConstants.legacyEmailSuffixes) {
        final legacyEmail = '$normalizedUsername$suffix';
        if (!candidateEmails.contains(legacyEmail)) {
          candidateEmails.add(legacyEmail);
        }
      }

      AuthResponse? response;
      AuthApiException? lastAuthError;

      for (final email in candidateEmails) {
        try {
          response = await _client.auth.signInWithPassword(
            email: email,
            password: password,
          );
          break;
        } on AuthApiException catch (e) {
          lastAuthError = e;
          if (e.message.contains('Invalid login credentials')) {
            continue;
          }
          rethrow;
        }
      }

      if (response == null) {
        throw lastAuthError ??
            const AuthException(message: 'فشل تسجيل الدخول');
      }

      if (response.user == null) {
        throw const AuthException(message: 'فشل تسجيل الدخول');
      }

      // Fetch agent record from agents table
      final agentData = await _client
          .from('agents')
          .select()
          .eq('id', response.user!.id)
          .single();

      // Cache agent for offline access
      final box = await Hive.openBox(_authCacheBox);
      await box.put(_agentKey, agentData);

      return AgentModel.fromJson(agentData);
    } on AuthApiException catch (e) {
      print('DEBUG: AuthApiException in SupabaseAuthDatasource: ${e.message} (code: ${e.statusCode})');
      throw AuthException(
        message: _mapAuthError(e.message),
        statusCode: e.statusCode != null ? int.tryParse(e.statusCode!) : null,
      );
    } catch (e) {
      print('DEBUG: Unexpected error in SupabaseAuthDatasource: $e');
      if (e is AuthException) rethrow;
      throw ServerException(message: 'خطأ في الاتصال بالسيرفر: $e');
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      final box = await Hive.openBox(_authCacheBox);
      await box.delete(_agentKey);
      await _client.auth.signOut();
    } catch (e) {
      throw ServerException(message: 'فشل تسجيل الخروج: $e');
    }
  }

  /// Get the currently authenticated agent.
  Future<AgentModel?> getCurrentAgent() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        final box = await Hive.openBox(_authCacheBox);
        await box.delete(_agentKey);
        return null;
      }

      try {
        final agentData = await _client
            .from('agents')
            .select()
            .eq('id', user.id)
            .single();

        final box = await Hive.openBox(_authCacheBox);
        await box.put(_agentKey, agentData);

        return AgentModel.fromJson(agentData);
      } catch (networkError) {
        // Fallback to cache if offline
        final box = await Hive.openBox(_authCacheBox);
        final cachedData = box.get(_agentKey);
        
        if (cachedData != null) {
          final Map<String, dynamic> mappedData = Map<String, dynamic>.from(cachedData as Map);
          return AgentModel.fromJson(mappedData);
        }
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Check if there is an active session.
  bool get isAuthenticated => _client.auth.currentSession != null;

  /// Get the current user's ID.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Map Supabase auth error messages to Arabic.
  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'اسم المستخدم أو كلمة المرور غير صحيح';
    }
    if (message.contains('Email not confirmed')) {
      return 'الحساب غير مفعّل';
    }
    if (message.contains('Too many requests')) {
      return 'محاولات كثيرة، يرجى الانتظار';
    }
    return 'خطأ في تسجيل الدخول: $message';
  }
}
