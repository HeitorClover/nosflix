import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cada perfil (Heitor / Leticia) tem sua própria paleta.
enum Profile { heitor, leticia }

extension ProfileX on Profile {
  String get displayName => switch (this) {
        Profile.heitor => 'Heitor',
        Profile.leticia => 'Leticia',
      };

  /// Cor principal: vermelho intenso (Heitor) / rosa vibrante (Leticia).
  Color get seedColor => switch (this) {
        Profile.heitor => const Color(0xFFFF2E3D),
        Profile.leticia => const Color(0xFFFF5FA2),
      };

  Color get lightColor => switch (this) {
        Profile.heitor => const Color(0xFFFF6B6B),
        Profile.leticia => const Color(0xFFFF9BC8),
      };

  Color get deepColor => switch (this) {
        Profile.heitor => const Color(0xFFA30F1B),
        Profile.leticia => const Color(0xFFC2185B),
      };

  /// Brilho no topo do fundo.
  Color get glowColor => switch (this) {
        Profile.heitor => const Color(0xFF3F0C11),
        Profile.leticia => const Color(0xFF45122F),
      };

  Color get baseColor => switch (this) {
        Profile.heitor => const Color(0xFF0B0506),
        Profile.leticia => const Color(0xFF0D060A),
      };

  Color get surfaceColor => switch (this) {
        Profile.heitor => const Color(0xFF1A0F11),
        Profile.leticia => const Color(0xFF1B1018),
      };

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [seedColor, deepColor],
      );
}

/// Cores extras do tema que não existem no ColorScheme.
class NosflixColors extends ThemeExtension<NosflixColors> {
  final LinearGradient gradient;
  final Color glow;
  final Color base;

  const NosflixColors({required this.gradient, required this.glow, required this.base});

  @override
  NosflixColors copyWith({LinearGradient? gradient, Color? glow, Color? base}) => NosflixColors(
        gradient: gradient ?? this.gradient,
        glow: glow ?? this.glow,
        base: base ?? this.base,
      );

  @override
  NosflixColors lerp(ThemeExtension<NosflixColors>? other, double t) {
    if (other is! NosflixColors) return this;
    return NosflixColors(
      gradient: LinearGradient.lerp(gradient, other.gradient, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      base: Color.lerp(base, other.base, t)!,
    );
  }
}

extension NosflixThemeX on BuildContext {
  NosflixColors get nx => Theme.of(this).extension<NosflixColors>()!;
}

class AppTheme {
  /// Tema escuro "cinema", com a paleta do perfil.
  static ThemeData build(Profile p) {
    final scheme = ColorScheme.dark(
      primary: p.seedColor,
      onPrimary: Colors.white,
      primaryContainer: p.deepColor,
      onPrimaryContainer: Colors.white,
      secondary: p.lightColor,
      onSecondary: Colors.black,
      surface: p.baseColor,
      onSurface: const Color(0xFFF6EFF1),
      onSurfaceVariant: const Color(0xFFB7A8AE),
      surfaceContainerLowest: p.baseColor,
      surfaceContainerLow: p.surfaceColor,
      surfaceContainer: p.surfaceColor,
      surfaceContainerHigh: Color.lerp(p.surfaceColor, Colors.white, 0.05)!,
      surfaceContainerHighest: Color.lerp(p.surfaceColor, Colors.white, 0.09)!,
      outlineVariant: Colors.white12,
      error: const Color(0xFFFF6B6B),
    );

    final base = ThemeData(brightness: Brightness.dark).textTheme;
    final text = GoogleFonts.outfitTextTheme(base)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: scheme.onSurface),
          headlineSmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface),
          titleLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
          titleMedium: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.baseColor,
      textTheme: text,
      extensions: [NosflixColors(gradient: p.gradient, glow: p.glowColor, base: p.baseColor)],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.seedColor, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.lightColor),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.seedColor,
        linearTrackColor: Colors.white10,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: Colors.white10),
    );
  }
}
