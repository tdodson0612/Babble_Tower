// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

/// App color palette, implemented as a Flutter ThemeExtension so both
/// light and dark variants remain fully `const` (required for `const
/// TextStyle(color: ...)` etc. used throughout the app) while still
/// resolving to the correct palette at runtime via Theme.of(context).
///
/// Usage in widgets:
///   context.colors.primary
///   context.colors.background
///   ...etc, same field names as before.
///
/// Migration note: existing `AppColors.primary` static references are
/// being replaced screen-by-screen with `context.colors.primary`.
/// AppColors below is kept ONLY as the static light-mode fallback for
/// any not-yet-migrated call site, and for non-widget contexts (e.g.
/// inside `const` declarations outside a BuildContext) where dark mode
/// support isn't reachable anyway.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color primary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color highlight;
  final Color border;

  const AppColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.highlight,
    required this.border,
  });

  // ── Light palette (also used as the static fallback) ──────────────────
  static const light = AppColors(
    background:    Color(0xFFF8F5F0),
    surface:       Color(0xFFFFFFFF),
    primary:       Color(0xFF2D5016), // deep forest green
    accent:        Color(0xFFC8860A), // warm amber
    textPrimary:   Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B6B6B),
    highlight:     Color(0xFFFFF3C4), // soft yellow tap highlight
    border:        Color(0xFFE0DDD8),
  );

  // ── Dark palette ────────────────────────────────────────────────────────
  static const dark = AppColors(
    background:    Color(0xFF14130F),
    surface:       Color(0xFF1F1E18),
    primary:       Color(0xFF6FA050), // lighter forest green for contrast
    accent:        Color(0xFFE0A838), // brighter amber for contrast
    textPrimary:   Color(0xFFF0EDE6),
    textSecondary: Color(0xFFA8A39A),
    highlight:     Color(0xFF3D3618), // dim amber tap highlight
    border:        Color(0xFF332F26),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? primary,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? highlight,
    Color? border,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      highlight: highlight ?? this.highlight,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

/// Ergonomic access: context.colors.primary instead of
/// Theme.of(context).extension<AppColors>()!.primary
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}