// lib/data/services/hive_service.dart

import 'package:hive_flutter/hive_flutter.dart';

/// Initializes Hive and registers all adapters.
/// Call [HiveService.init] once in main() before runApp().
class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    // Register type adapters here as you add them.
    // e.g. Hive.registerAdapter(UserProfileAdapter());
    //
    // Currently using untyped Map boxes for simplicity.
    // Add generated adapters when you run build_runner for Hive models.
  }

  /// Opens a named box if not already open, else returns the open box.
  static Future<Box> openBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box(name);
    return Hive.openBox(name);
  }

  /// Closes all open boxes. Call on app suspend/terminate if needed.
  static Future<void> closeAll() async {
    await Hive.close();
  }

  /// Deletes ALL data for a given box. Use with caution.
  static Future<void> clearBox(String name) async {
    final box = await openBox(name);
    await box.clear();
  }

  // ---------------------------------------------------------------------------
  // Known box names — centralised to avoid magic strings across the app
  // ---------------------------------------------------------------------------

  static const String settings        = 'settings';
  static const String userProfile     = 'user_profile';
  static const String readingProgress = 'reading_progress';

  // Vocabulary boxes are keyed dynamically: "vocab_{pairKey}"

  /// Per-verse progress (Phase 6) — known words, accuracy, completion
  /// state, retry count. Separate from [readingProgress], which only
  /// tracks coarse block-unlock state. Keyed dynamically per language
  /// pair: "verse_progress_{pairKey}" — see [verseProgressBoxName].
  static String verseProgressBoxName(String pairKey) =>
      'verse_progress_$pairKey';

  /// Grammar-parsing accuracy by category (Phase 10) — keyed per language
  /// pair: "parsing_progress_{pairKey}" — see [parsingProgressBoxName].
  static String parsingProgressBoxName(String pairKey) =>
      'parsing_progress_$pairKey';
}