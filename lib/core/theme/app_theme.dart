import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app is dark-only: posters are the loud element on every screen, and a
/// dark ground lets them carry the colour instead of competing with a bright
/// surface.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF6C5CE7);

  /// Deep navy rather than the neutral grey `fromSeed` picks: posters read as
  /// warmer against it, and it is what the reference design uses.
  static const Color _surface = Color(0xFF14162E);
  static const Color _surfaceRaised = Color(0xFF1E2140);

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ).copyWith(
          surface: _surface,
          surfaceContainerHighest: _surfaceRaised,
          onSurfaceVariant: const Color(0xFFB9BCD6),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        // The glass bar paints its own background; anything here would sit on
        // top of the blur and defeat it.
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.25),
        space: 1,
        thickness: 1,
      ),
    );
  }
}
