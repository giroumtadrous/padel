import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — Light Cream theme
  static const Color primary = Color(0xFFE63946); // Red CTA
  static const Color secondary = Color(0xFF1565A7); // Blue accent
  static const Color accent = Color(0xFFF7C948); // Gold

  // Backgrounds
  static const Color background = Color(0xFFF7F5F2); // Warm cream
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color card = Color(0xFFFFFFFF); // Card white
  static const Color cardElevated = Color(0xFFF0ECE6); // Slightly deeper cream

  // Navy
  static const Color navy = Color(0xFF0B1F3A); // Dark navy header
  static const Color navyLight = Color(0xFF112840); // Slightly lighter navy
  static const Color navyMid = Color(0xFF1565A7); // Mid blue

  // Text
  static const Color textPrimary = Color(0xFF0B1F3A); // Dark navy on light bg
  static const Color textSecondary = Color(0xFF6B7280); // Gray
  static const Color textHint = Color(0xFFADB5BD); // Light gray
  static const Color textOnDark = Color(0xFFFFFFFF); // White on dark
  static const Color textBlueGrey = Color(0xFF7A9BBF); // Blue-grey on dark

  // Success
  static const Color success = Color(0xFF3B6D11); // Dark green
  static const Color successLight = Color(0xFFEAF3DE); // Light green bg

  // Error / Status
  static const Color error = Color(0xFFE63946);
  static const Color warning = Color(0xFFF7C948);

  // Slot states
  static const Color peakHour = Color(0xFFE63946); // Red for peak
  static const Color offPeak = Color(0xFF3B6D11); // Green for off-peak

  // Borders / Dividers
  static const Color divider = Color(0xFFE5E0D8); // Warm border
  static const Color border = Color(0xFFE5E0D8);

  // Shimmer
  static const Color shimmerBase = Color(0xFFEDE8E1);
  static const Color shimmerHighlight = Color(0xFFF7F5F2);

  // Gold badge
  static const Color gold = Color(0xFFF7C948);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE63946), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navyGradient = LinearGradient(
    colors: [Color(0xFF0B1F3A), Color(0xFF1565A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
