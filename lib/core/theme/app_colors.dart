import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF0075db);
  static const Color accentOrange = Color(0xFFf59e0b);
  static const Color success = Color(0xFF10b981);
  static const Color error = Color(0xFFef4444);
  static const Color warning = Color(0xFFf59e0b);

  // Light Mode Colors
  static const Color bgLight = Color(0xFFf5f7f8);
  static const Color surfaceLight = Colors.white;
  static const Color borderLight = Color(0xFFe2e8f0);
  static const Color textLight = Color(0xFF0f172a);
  static const Color labelLight = Color(0xFF64748b);
  static const Color inputBgLight = Color(0xFFf8fafc);

  // Dark Mode Colors
  static const Color bgDark = Color(0xFF0f1a23);
  static const Color surfaceDark = Color(0xFF1b2631);
  static const Color borderDark = Color(0xFF1e293b);
  static const Color textDark = Colors.white;
  static const Color labelDark = Color(0xFF94a3b8);
  static const Color inputBgDark = Color(0xFF1b2631);

  // Helpers
  static Color getBackground(bool isDarkMode) => isDarkMode ? bgDark : bgLight;
  static Color getSurface(bool isDarkMode) =>
      isDarkMode ? surfaceDark : surfaceLight;
  static Color getBorder(bool isDarkMode) =>
      isDarkMode ? borderDark : borderLight;
  static Color getText(bool isDarkMode) => isDarkMode ? textDark : textLight;
  static Color getLabel(bool isDarkMode) => isDarkMode ? labelDark : labelLight;
}
