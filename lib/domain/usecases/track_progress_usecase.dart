// lib/domain/usecases/track_progress_usecase.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/reading_progress_model.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/prefs_service.dart';

/// Saves and retrieves reading progress for a given language pair.
/// Handles block unlocking and last-position tracking.
class TrackProgressUseCase {
  const TrackProgressUseCase();

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Returns saved progress for [pairKey], or a fresh model if none exists.
  Future<ReadingProgressModel> load(String pairKey) async {
    try {
      final box = await HiveService.openBox(HiveService.readingProgress);
      final raw = box.get(pairKey);
      if (raw == null) return ReadingProgressModel.fresh(pairKey);
      return ReadingProgressModel.fromMap(raw as Map);
    } catch (_) {
      return ReadingProgressModel.fresh(pairKey);
    }
  }

  // ---------------------------------------------------------------------------
  // Save position
  // ---------------------------------------------------------------------------

  /// Updates the user's last-read position (Hive + PrefsService).
  Future<void> savePosition({
    required String pairKey,
    required String book,
    required int chapter,
    required int blockIndex,
  }) async {
    // Persist to Hive model
    final current = await load(pairKey);
    final updated = current.copyWith(
      book:       book,
      chapter:    chapter,
      blockIndex: blockIndex,
      lastReadAt: DateTime.now(),
    );
    await _persist(updated);

    // Mirror to PrefsService so resume card works without loading Hive
    await PrefsService.savePosition(
      pairKey: pairKey,
      book:    book,
      chapter: chapter,
      block:   blockIndex,
    );
  }

  // ---------------------------------------------------------------------------
  // Unlock block
  // ---------------------------------------------------------------------------

  /// Marks a block as unlocked (user met the 80% mastery threshold).
  Future<ReadingProgressModel> unlockBlock({
    required String pairKey,
    required String book,
    required int chapter,
    required int blockIndex,
  }) async {
    final current = await load(pairKey);
    final updated =
        current.unlockBlock(book, chapter, blockIndex).copyWith(
              lastReadAt: DateTime.now(),
            );
    await _persist(updated);

    // Mirror to PrefsService
    await PrefsService.unlockBlock(
      pairKey: pairKey,
      book:    book,
      chapter: chapter,
      block:   blockIndex,
    );

    return updated;
  }

  // ---------------------------------------------------------------------------
  // Check unlock
  // ---------------------------------------------------------------------------

  Future<bool> isBlockUnlocked({
    required String pairKey,
    required String book,
    required int chapter,
    required int blockIndex,
  }) async {
    // Block 0 is always unlocked — it's the entry point
    if (blockIndex == 0) return true;
    final progress = await load(pairKey);
    return progress.isBlockUnlocked(book, chapter, blockIndex);
  }

  // ---------------------------------------------------------------------------
  // Highest block reached
  // ---------------------------------------------------------------------------

  /// Returns the highest block index the user has ever reached for [pairKey].
  /// Reads from PrefsService (sync-friendly) rather than awaiting Hive.
  Future<int> highestBlock({required String pairKey}) async {
    // PrefsService is the fast path (already in memory after init)
    final fromPrefs = PrefsService.highestBlock(pairKey: pairKey);
    if (fromPrefs > 0) return fromPrefs;

    // Fall back to Hive model in case PrefsService was just initialised
    try {
      final progress = await load(pairKey);
      return progress.blockIndex;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clears all progress for [pairKey]. Called when user changes L2.
  Future<void> reset(String pairKey) async {
    final box = await HiveService.openBox(HiveService.readingProgress);
    await box.delete(pairKey);
    await PrefsService.resetProgress(pairKey);
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _persist(ReadingProgressModel model) async {
    final box = await HiveService.openBox(HiveService.readingProgress);
    await box.put(model.key, model.toMap());
  }
}