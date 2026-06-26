// lib/presentation/providers/settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/prefs_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class SettingsState {
  /// When false, words already mastered are hidden in Learn/Test modes.
  final bool showKnownWords;

  /// Font scale multiplier applied to verse text (0.8 – 1.6).
  final double textScale;

  /// Whether haptic feedback is enabled on word tap.
  final bool hapticFeedback;

  /// Whether dark mode is enabled.
  final bool darkMode;

  const SettingsState({
    this.showKnownWords = true,
    this.textScale = 1.0,
    this.hapticFeedback = true,
    this.darkMode = false,
  });

  SettingsState copyWith({
    bool? showKnownWords,
    double? textScale,
    bool? hapticFeedback,
    bool? darkMode,
  }) =>
      SettingsState(
        showKnownWords: showKnownWords ?? this.showKnownWords,
        textScale: textScale ?? this.textScale,
        hapticFeedback: hapticFeedback ?? this.hapticFeedback,
        darkMode: darkMode ?? this.darkMode,
      );

  Map<String, dynamic> toMap() => {
        'showKnownWords': showKnownWords,
        'textScale': textScale,
        'hapticFeedback': hapticFeedback,
        'darkMode': darkMode,
      };

  factory SettingsState.fromMap(Map<dynamic, dynamic> m) => SettingsState(
        showKnownWords: m['showKnownWords'] as bool? ?? true,
        textScale: (m['textScale'] as num?)?.toDouble() ?? 1.0,
        hapticFeedback: m['hapticFeedback'] as bool? ?? true,
        darkMode: m['darkMode'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _boxName = 'settings';
  static const _key = 'prefs';

  // PrefsService mirror keys — kept as constants to avoid typos across
  // _load() and _persist().
  static const _kShowKnown = 'setting_show_known';
  static const _kTextScale = 'setting_text_scale';
  static const _kHaptic = 'setting_haptic';
  static const _kDarkMode = 'setting_dark_mode';

  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    // Try Hive first (rich storage), then fall back to PrefsService mirrors.
    try {
      final box = await HiveService.openBox(_boxName);
      final raw = box.get(_key);
      if (raw != null) {
        state = SettingsState.fromMap(raw as Map);
        return;
      }
    } catch (_) {
      // Hive unavailable — fall through to PrefsService
    }

    // PrefsService fallback — requires rawGetBool / rawGetDouble in PrefsService
    state = SettingsState(
      showKnownWords: PrefsService.rawGetBool(_kShowKnown) ?? true,
      textScale: PrefsService.rawGetDouble(_kTextScale) ?? 1.0,
      hapticFeedback: PrefsService.rawGetBool(_kHaptic) ?? true,
      darkMode: PrefsService.rawGetBool(_kDarkMode) ?? false,
    );
  }

  Future<void> _persist() async {
    // Write to both Hive and PrefsService so settings survive on all platforms.
    final box = await HiveService.openBox(_boxName);
    await box.put(_key, state.toMap());
    await PrefsService.rawSetBool(_kShowKnown, state.showKnownWords);
    await PrefsService.rawSetDouble(_kTextScale, state.textScale);
    await PrefsService.rawSetBool(_kHaptic, state.hapticFeedback);
    await PrefsService.rawSetBool(_kDarkMode, state.darkMode);
  }

  void toggleShowKnownWords() {
    state = state.copyWith(showKnownWords: !state.showKnownWords);
    _persist();
  }

  void setTextScale(double scale) {
    state = state.copyWith(textScale: scale.clamp(0.8, 1.6));
    _persist();
  }

  void toggleHaptic() {
    state = state.copyWith(hapticFeedback: !state.hapticFeedback);
    _persist();
  }

  void toggleDarkMode() {
    final newValue = !state.darkMode;
    state = state.copyWith(darkMode: newValue);
    _persist();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);