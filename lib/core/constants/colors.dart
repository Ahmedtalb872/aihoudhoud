import 'package:flutter/material.dart';

class AppColors {
  // Brand colors sampled from the current Trend Ride Driver logo (a neon
  // green ring + gold "TAXI"/"Ride" accents on a near-black circular
  // badge) - primary is the logo's vivid neon green, primaryDark a deeper
  // shade of it for text/borders/icons sitting on white backgrounds where
  // the brighter primary itself would be low-contrast, and accent is the
  // logo's gold highlight color.
  static const Color primary = Color(0xFF2E9E15);
  static const Color primaryDark = Color(0xFF175C0C);
  static const Color secondary = Color(0xFF1C1C1C);
  static const Color accent = Color(0xFFF5D000);
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
