// lib/core/constants/app_text_styles.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Text styles that depend on theme colors. Since AppColors is now a
/// ThemeExtension (resolved at runtime via context), these can no
/// longer be `static const` — they're methods that take a
/// BuildContext and return the correctly-themed TextStyle.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle headline(BuildContext context) => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
        height: 1.1,
      );

  static TextStyle subheadline(BuildContext context) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: context.colors.textPrimary,
      );

  static TextStyle body(BuildContext context) => TextStyle(
        fontSize: 15,
        color: context.colors.textSecondary,
        height: 1.5,
      );

  static TextStyle verseText(BuildContext context) => TextStyle(
        fontSize: 18,
        color: context.colors.textPrimary,
        height: 1.8,
        fontWeight: FontWeight.w400,
      );

  static TextStyle verseNumber(BuildContext context) => TextStyle(
        fontSize: 12,
        color: context.colors.accent,
        fontWeight: FontWeight.w700,
      );

  static TextStyle wordHighlight(BuildContext context) => TextStyle(
        fontSize: 18,
        color: context.colors.primary,
        height: 1.8,
        fontWeight: FontWeight.w600,
      );

  static TextStyle label(BuildContext context) => TextStyle(
        fontSize: 12,
        color: context.colors.textSecondary,
      );
}