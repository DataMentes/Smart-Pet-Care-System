// lib/main.dart
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart'; // ✅  التصحيح: استيراد البروفايدر
import 'features/auth/presentation/screens/auth_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅  التصحيح: استخدام ValueListenableBuilder للاستماع للتغييرات
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeProvider.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Pet Care',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode, // استخدام المظهر الحالي من الـ Notifier
          home: const AuthScreen(),
        );
      },
    );
  }
}
