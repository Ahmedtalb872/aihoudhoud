import 'package:flutter/material.dart';

class AppColors {
  // Brand green/black from the TRENDE logo (sampled directly from its
  // artwork), replacing the previous gold scheme after the app's rebrand.
  // primaryDark is a deeper green for text/borders/icons sitting on white
  // backgrounds, where the brighter primary itself would be low-contrast.
  static const Color primary = Color(0xFF0B7A3E);
  static const Color primaryDark = Color(0xFF0E4A2C);
  static const Color secondary = Color(0xFF1C1C1C);
  static const Color accent = Color(0xFF22C55E);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color darkText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);

  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  static const Color border = Color(0xFFE2E8F0);
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF1F5F9);
}
