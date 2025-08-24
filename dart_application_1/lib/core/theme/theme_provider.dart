// lib/core/theme/theme_provider.dart
import 'package:flutter/material.dart';

// هذا الكلاس سيحتوي على الـ Notifier الخاص بنا
class ThemeProvider {
  // ValueNotifier هو كلاس بسيط من Flutter يقوم بإعلام "المستمعين" عند تغيير قيمته
  static ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );
}
