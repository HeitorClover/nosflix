import 'package:flutter/material.dart';

/// Cada perfil (Heitor / Leticia) tem seu próprio tema de cor.
enum Profile { heitor, leticia }

extension ProfileX on Profile {
  String get displayName => switch (this) {
        Profile.heitor => 'Heitor',
        Profile.leticia => 'Leticia',
      };

  Color get seedColor => switch (this) {
        Profile.heitor => const Color(0xFFE53935), // vermelho
        Profile.leticia => const Color(0xFFEC407A), // rosa
      };
}

class AppTheme {
  static ThemeData light(Profile profile) {
    final scheme = ColorScheme.fromSeed(
      seedColor: profile.seedColor,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark(Profile profile) {
    final scheme = ColorScheme.fromSeed(
      seedColor: profile.seedColor,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainerHigh,
        labelStyle: TextStyle(color: scheme.onSurface),
        shape: const StadiumBorder(),
      ),
    );
  }
}
