// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

/// App color palette, implemented as a Flutter ThemeExtension so both
/// light and dark variants remain fully `const` (required for `const
/// TextStyle(color: ...)` etc. used throughout the app) while still
/// resolving to the correct palette at runtime via Theme.of(context).
///
/// Usage in widgets:
///   context.colors.primary
///   context.colors.secondary
///   context.colors.background
///   ...etc.
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

  /// New baby-blue accent used for informational UI.
  final Color secondary;

  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color highlight;
  final Color border;

  const AppColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.highlight,
    required this.border,
  });

  // ── Light palette (also used as the static fallback) ──────────────────
  static const light = AppColors(
    background: Color(0xFFF8F5F0),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF2D5016), // deep forest green
    secondary: Color(0xFFAEC6FF), // baby blue
    accent: Color(0xFFC8860A), // warm amber
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B6B6B),
    highlight: Color(0xFFFFF3C4), // soft yellow tap highlight
    border: Color(0xFFE0DDD8),
  );

  // ── Dark palette ────────────────────────────────────────────────────────
  static const dark = AppColors(
    background: Color(0xFF14130F),
    surface: Color(0xFF1D232A), // slightly cool dark slate
    primary: Color(0xFF6FA050), // lighter forest green for contrast
    secondary: Color(0xFF8EC5FF), // baby blue
    accent: Color(0xFFE0A838), // brighter amber for contrast
    textPrimary: Color(0xFFF0EDE6),
    textSecondary: Color(0xFFA8A39A),
    highlight: Color(0xFF3D3618), // dim amber tap highlight
    border: Color(0xFF332F26),
  );

  // ── Unlockable themes ──────────────────────────────────────────────────
  // Cosmetic-only alternate palettes, gated behind RewardsService's
  // variable-reward "mystery box" unlocks (see rewards_service.dart) —
  // not tied to light/dark mode, purely a collectible reward. Each
  // keeps the same text/border relationships as `light` for contrast
  // safety, only primary/secondary/accent/highlight actually shift.
  static const ocean = AppColors(
    background: Color(0xFFF3F8FA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF0F6E8C),
    secondary: Color(0xFF8FD3E8),
    accent: Color(0xFF1FA598),
    textPrimary: Color(0xFF13262B),
    textSecondary: Color(0xFF5A7379),
    highlight: Color(0xFFD5F0F5),
    border: Color(0xFFD9E7EA),
  );

  static const sunset = AppColors(
    background: Color(0xFFFBF4EF),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFFCC5B32),
    secondary: Color(0xFFFFC38B),
    accent: Color(0xFFE0447B),
    textPrimary: Color(0xFF2E1B14),
    textSecondary: Color(0xFF7A655C),
    highlight: Color(0xFFFFE3CE),
    border: Color(0xFFEFDCD1),
  );

  static const royal = AppColors(
    background: Color(0xFFF6F3FA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF5B3E96),
    secondary: Color(0xFFC9B6F2),
    accent: Color(0xFFC9A227),
    textPrimary: Color(0xFF221A33),
    textSecondary: Color(0xFF6E6580),
    highlight: Color(0xFFE9E1F7),
    border: Color(0xFFE0D8EC),
  );

  static const midnight = AppColors(
    background: Color(0xFF0B0E17),
    surface: Color(0xFF161B29),
    primary: Color(0xFF7C93FF),
    secondary: Color(0xFF9AD8FF),
    accent: Color(0xFFC0C7D9),
    textPrimary: Color(0xFFEDEFF7),
    textSecondary: Color(0xFF9AA1B8),
    highlight: Color(0xFF232B45),
    border: Color(0xFF262C40),
  );

  /// Every unlockable theme, keyed by the same id RewardsService uses
  /// in its persisted "unlocked theme ids" set. Deliberately excludes
  /// `light`/`dark` — those are the always-available base modes, not
  /// unlockable rewards.
  static const Map<String, AppColors> unlockableThemes = {
    'ocean': ocean,
    'sunset': sunset,
    'royal': royal,
    'midnight': midnight,
  };

  static AppColors? byUnlockableId(String id) => unlockableThemes[id];

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? primary,
    Color? secondary,
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
      secondary: secondary ?? this.secondary,
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
      secondary: Color.lerp(secondary, other.secondary, t)!,
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