// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅  التصحيح: إضافة هذا السطر

class AppTheme {
  static const Color _primaryColor = Color(0xFF25C1A9);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF0F4F8),
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: _primaryColor,
        secondary: _primaryColor,
      ),
      // ✅  التصحيح: إضافة هذا الجزء للمظهر الفاتح
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          // اجعل أيقونات شريط الحالة داكنة
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light, // For iOS
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme(isDark: false),
      tabBarTheme: _tabBarTheme,
      cardColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.05),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        secondary: _primaryColor,
        surface: Color(0xFF1E1E1E),
      ),
      // ✅  التصحيح: إضافة هذا الجزء للمظهر الداكن
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          // اجعل أيقونات شريط الحالة فاتحة
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // For iOS
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme(isDark: true),
      tabBarTheme: _tabBarTheme,
      cardColor: const Color(0xFF1E1E1E),
      shadowColor: Colors.black.withOpacity(0.2),
    );
  }

  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  );

  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _primaryColor),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
      ),
    );
  }

  static const TabBarThemeData _tabBarTheme = TabBarThemeData(
    labelColor: _primaryColor,
    unselectedLabelColor: Colors.grey,
    indicatorColor: _primaryColor,
  );
}
