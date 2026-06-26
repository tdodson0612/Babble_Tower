// lib/presentation/providers/language_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/supported_languages.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Babble Tower has exactly one language pair: English speakers learning
/// to read Koine Greek. This state exists mainly to preserve the
/// `pairKey` API used throughout vocabulary/progress storage, without
/// requiring every caller to be rewritten.
class LanguageState {
  final String nativeCode;
  final String nativeName;
  final String targetCode;
  final String targetName;
  final String targetNativeName;

  const LanguageState({
    this.nativeCode = AppLanguage.nativeCode,
    this.nativeName = AppLanguage.nativeName,
    this.targetCode = AppLanguage.targetCode,
    this.targetName = AppLanguage.targetName,
    this.targetNativeName = AppLanguage.targetNativeName,
  });

  /// Always true — there is nothing left to "complete" by selection.
  bool get isComplete => true;

  /// Composite key used for vocabulary storage, e.g. "en_el".
  String get pairKey => AppLanguage.pairKey;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// No mutation methods remain — the pair is fixed at compile time.
/// Kept as a StateNotifier (rather than a plain Provider) so existing
/// `ref.watch(languageProvider)` / `ref.read(languageProvider)` call
/// sites across the app continue to work unchanged.
class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(const LanguageState());
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final languageProvider =
    StateNotifierProvider<LanguageNotifier, LanguageState>(
  (ref) => LanguageNotifier(),
);