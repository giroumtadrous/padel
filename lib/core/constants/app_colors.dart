import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFC6FF00);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color accent = Color(0xFFFF6D00);

  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF14141C);
  static const Color card = Color(0xFF1E1E2A);
  static const Color cardElevated = Color(0xFF252535);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color textHint = Color(0xFF4A4A5A);

  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFF6D00);

  static const Color peakHour = Color(0xFFFF6D00);
  static const Color offPeak = Color(0xFFC6FF00);

  static const Color divider = Color(0xFF2A2A3A);
  static const Color shimmerBase = Color(0xFF1E1E2A);
  static const Color shimmerHighlight = Color(0xFF2A2A3A);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC6FF00), Color(0xFF8BC34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF14141C), Color(0xFF0A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
