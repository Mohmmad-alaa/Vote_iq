import 'package:flutter/material.dart';

/// Application color palette — Premium Light Blue & Gold theme.
class AppColors {
  AppColors._();

  // ── Primary (Rich Royal Blue) ──
  static const Color primary = Color(0xFF1565C0);       // أزرق ملكي
  static const Color primaryLight = Color(0xFF1E88E5);  // أزرق فاتح
  static const Color primaryDark = Color(0xFF0D47A1);   // أزرق داكن
  static const Color primarySurface = Color(0xFFE3F2FD); // خلفية أزرق شفافة

  // ── Accent (Rich Gold) ──
  static const Color accent = Color(0xFFF9A825);        // ذهبي غني
  static const Color accentLight = Color(0xFFFFCC02);   // ذهبي فاتح
  static const Color accentDark = Color(0xFFF57F17);    // ذهبي داكن
  static const Color accentSurface = Color(0xFFFFF8E1); // خلفية ذهبية شفافة

  // ── Status Colors ──
  static const Color statusVoted    = Color(0xFF2E7D32); // أخضر داكن
  static const Color statusNotVoted = Color(0xFF455A64); // رمادي مزرق
  static const Color statusRefused  = Color(0xFFC62828); // أحمر داكن
  static const Color statusNotFound = Color(0xFFF57C00); // برتقالي داكن
  static const Color statusVotedBg    = Color(0xFFE8F5E9);
  static const Color statusNotVotedBg = Color(0xFFECEFF1);
  static const Color statusRefusedBg  = Color(0xFFFFEBEE);
  static const Color statusNotFoundBg = Color(0xFFFFF3E0);

  // ── Backgrounds ──
  static const Color scaffoldBg = Color(0xFFF0F4FA); // رمادي مزرق فاتح جداً
  static const Color cardBg     = Colors.white;
  static const Color surfaceBg  = Color(0xFFF8FAFF); // أبيض مزرق

  // ── Text ──
  static const Color textPrimary   = Color(0xFF0D1B35); // كحلي داكن جداً
  static const Color textSecondary = Color(0xFF546E8A); // رمادي مزرق
  static const Color textHint      = Color(0xFF90A4AE); // رمادي فاتح
  static const Color textOnPrimary = Colors.white;

  // ── Borders & Dividers ──
  static const Color divider = Color(0xFFDDE4EE);
  static const Color border  = Color(0xFFBECCDD);

  // ── Shadows ──
  static const Color shadowBlue = Color(0x1A1565C0); // ظل أزرق شفاف
  static const Color shadowDark = Color(0x0D0D1B35); // ظل داكن شفاف

  // ── Semantic ──
  static const Color error   = Color(0xFFC62828);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color info    = Color(0xFF1565C0);

  // ── Sync Indicators ──
  static const Color online  = Color(0xFF2E7D32);
  static const Color offline = Color(0xFFC62828);
  static const Color syncing = Color(0xFFF9A825);

  // ── Gradient Presets ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9A825), Color(0xFFF57F17)],
  );

  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
  );
}
