// lib/presentation/providers/user_profile_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/prefs_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class UserProfileState {
  final UserProfileModel? profile;
  final bool isLoading;
  final bool hasCompletedAlphabet;
  final bool hasCompletedOnboarding;

  const UserProfileState({
    this.profile,
    this.isLoading = true,
    this.hasCompletedAlphabet = false,
    this.hasCompletedOnboarding = false,
  });

  UserProfileState copyWith({
    UserProfileModel? profile,
    bool? isLoading,
    bool? hasCompletedAlphabet,
    bool? hasCompletedOnboarding,
  }) =>
      UserProfileState(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        hasCompletedAlphabet:
            hasCompletedAlphabet ?? this.hasCompletedAlphabet,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Babble Tower teaches a single fixed pair (English speakers reading
/// Koine Greek), so there is no language selection step anymore.
/// A profile is created automatically on first launch if none exists.
/// This notifier now only tracks alphabet-lesson and onboarding
/// completion flags.
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier() : super(const UserProfileState()) {
    _load();
  }

  static const _boxKey = 'profile';

  Future<void> _load() async {
    try {
      // Prefer PrefsService flags (survive Hive box corruption / web issues).
      final box = await HiveService.openBox(HiveService.userProfile);
      final raw = box.get(_boxKey);

      if (raw == null) {
        // No Hive profile yet — auto-create one (first launch).
        await _createProfile();
        return;
      }

      final profile = UserProfileModel.fromMap(raw as Map);

      // Merge: prefer PrefsService flags over stale Hive booleans
      final alphabetDone =
          PrefsService.alphabetDone || profile.hasCompletedAlphabet;
      final onboardingDone =
          PrefsService.onboardingDone || profile.hasCompletedOnboarding;

      state = UserProfileState(
        profile: profile,
        isLoading: false,
        hasCompletedAlphabet: alphabetDone,
        hasCompletedOnboarding: onboardingDone,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Creates the (only) profile on first launch.
  Future<void> _createProfile() async {
    final profile = UserProfileModel.fresh();
    await _persist(profile);
    await PrefsService.setOnboardingDone(true);
    state = UserProfileState(
      profile: profile,
      isLoading: false,
      hasCompletedAlphabet: false,
      hasCompletedOnboarding: true,
    );
  }

  /// Called when the user finishes OR skips the alphabet lesson.
  Future<void> completeAlphabet() async {
    // Always write to PrefsService first — this is the fix for the gate bug.
    await PrefsService.setAlphabetDone(true);

    final current = state.profile;
    if (current != null) {
      final updated = current.copyWith(hasCompletedAlphabet: true);
      await _persist(updated);
      state = state.copyWith(
        profile: updated,
        hasCompletedAlphabet: true,
      );
    } else {
      // No Hive profile yet — shouldn't normally happen since _load()
      // auto-creates one, but handle defensively.
      state = state.copyWith(hasCompletedAlphabet: true);
    }
  }

  /// Called after first successful chapter load.
  Future<void> completeOnboarding() async {
    await PrefsService.setOnboardingDone(true);

    final current = state.profile;
    if (current == null) return;
    final updated = current.copyWith(hasCompletedOnboarding: true);
    await _persist(updated);
    state = state.copyWith(
      profile: updated,
      hasCompletedOnboarding: true,
    );
  }

  Future<void> _persist(UserProfileModel model) async {
    final box = await HiveService.openBox(HiveService.userProfile);
    await box.put(_boxKey, model.toMap());
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>(
  (ref) => UserProfileNotifier(),
);