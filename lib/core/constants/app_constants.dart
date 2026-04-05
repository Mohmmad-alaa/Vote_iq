import 'dart:convert';

/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Vote IQ';
  static const String appNameAr = 'متابعة الناخبين';

  /// Email suffix used for Supabase Auth login.
  /// Username "ahmad" becomes "ahmad@voteiq.example.com".
  static const String emailSuffix = '@voteiq.example.com';
  static const List<String> legacyEmailSuffixes = [
    '@app.local',
    '@voteiq.local',
  ];

  static String normalizeUsername(String username) => username.trim();

  static String buildAgentEmail(String username) {
    final normalized = normalizeUsername(username);
    final asciiSafe = normalized.toLowerCase();

    if (RegExp(r'^[a-z0-9._-]+$').hasMatch(asciiSafe)) {
      return '$asciiSafe$emailSuffix';
    }

    final encoded = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
    return 'u_$encoded$emailSuffix';
  }

  /// Number of voters fetched per page (lazy loading).
  static const int pageSize = 50;

  /// Search debounce delay in milliseconds.
  static const int searchDebounceMs = 300;

  // ── Voter Status Values ──
  static const String statusNotVoted = 'لم يصوت';
  static const String statusVoted = 'تم التصويت';
  static const String statusRefused = 'رفض';

  // ── Agent Roles ──
  static const String roleAdmin = 'admin';
  static const String roleAgent = 'agent';

  // ── Hive Box Names ──
  static const String hiveVotersBox = 'voters_cache';
  static const String hiveLookupBox = 'lookup_cache';
  static const String hiveSyncQueueBox = 'sync_queue';
  static const String hiveSettingsBox = 'settings';
}
