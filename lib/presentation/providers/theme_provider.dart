// lib/presentation/providers/theme_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/rewards_service.dart';

/// Wraps RewardsService's active-theme persistence in a Riverpod
/// StateNotifier so app.dart (and the Settings theme picker) can
/// react live to a theme change — RewardsService itself is plain
/// SharedPreferences with no reactivity of its own, by design (see
/// its own doc comment for why it's kept independent of the rest of
/// the app's state management).
class ThemeState {
  final String? activeThemeId;
  final Set<String> unlockedThemeIds;

  const ThemeState({
    this.activeThemeId,
    this.unlockedThemeIds = const {},
  });

  /// The actual AppColors to apply, or null to mean "use normal
  /// light/dark mode" (no unlockable theme active).
  AppColors? get activeColors =>
      activeThemeId != null ? AppColors.byUnlockableId(activeThemeId!) : null;
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final RewardsService _rewards;

  ThemeNotifier(this._rewards) : super(const ThemeState()) {
    _load();
  }

  Future<void> _load() async {
    final activeId = await _rewards.activeThemeId;
    final unlocked = await _rewards.unlockedThemeIds;
    state = ThemeState(activeThemeId: activeId, unlockedThemeIds: unlocked);
  }

  /// Re-reads unlocked theme ids from storage — call this after a
  /// mystery box unlock so a newly-unlocked theme shows up in the
  /// Settings picker without needing to fully restart the provider.
  Future<void> refreshUnlocked() async {
    final unlocked = await _rewards.unlockedThemeIds;
    state = ThemeState(
      activeThemeId: state.activeThemeId,
      unlockedThemeIds: unlocked,
    );
  }

  Future<void> setTheme(String? themeId) async {
    await _rewards.setActiveTheme(themeId);
    state = ThemeState(
      activeThemeId: themeId,
      unlockedThemeIds: state.unlockedThemeIds,
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(RewardsService()),
);