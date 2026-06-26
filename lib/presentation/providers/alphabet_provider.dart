// lib/presentation/providers/alphabet_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/alphabet_data.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class AlphabetState {
  /// Index of the letter currently being studied.
  final int currentIndex;

  /// Set of letter indices the user has marked as mastered this session.
  final Set<int> masteredIndices;

  /// Whether the alphabet lesson has been fully completed.
  final bool isCompleted;

  const AlphabetState({
    this.currentIndex = 0,
    this.masteredIndices = const {},
    this.isCompleted = false,
  });

  double get masteryPercent {
    if (masteredIndices.isEmpty) return 0.0;
    return masteredIndices.length /
        (masteredIndices.length + 1); // rough progress
  }

  AlphabetState copyWith({
    int? currentIndex,
    Set<int>? masteredIndices,
    bool? isCompleted,
  }) =>
      AlphabetState(
        currentIndex: currentIndex ?? this.currentIndex,
        masteredIndices: masteredIndices ?? this.masteredIndices,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Babble Tower teaches a single fixed alphabet (Koine Greek), so this
/// notifier no longer looks up alphabet data by language code — it
/// always uses the Greek alphabet data set.
class AlphabetNotifier extends StateNotifier<AlphabetState> {
  AlphabetNotifier() : super(const AlphabetState());

  AlphabetData get _data => greekAlphabetData;

  int get _total => _data.letters.length;

  void markMastered(int index) {
    final newMastered = {...state.masteredIndices, index};
    final allDone = newMastered.length >= _total;
    state = state.copyWith(
      masteredIndices: newMastered,
      isCompleted: allDone,
    );
  }

  void goTo(int index) {
    if (index >= 0 && index < _total) {
      state = state.copyWith(currentIndex: index);
    }
  }

  void next() {
    if (state.currentIndex < _total - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    } else {
      state = state.copyWith(isCompleted: true);
    }
  }

  void prev() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  /// Resets the session (e.g. user wants to restudy from the start).
  void reset() => state = const AlphabetState();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final alphabetProvider =
    StateNotifierProvider<AlphabetNotifier, AlphabetState>(
  (ref) => AlphabetNotifier(),
);