// lib/data/models/grammar_lesson_progress_model.dart

/// Tracks, per specific grammar VALUE (a "categoryName:code" key — e.g.
/// "grammaticalCase:G" for Genitive, "tense:A" for Aorist — see
/// grammarKey() in grammar_lesson_engine.dart), when the Grammar lesson
/// last taught it. A SEPARATE, simpler model from ParsingProgressModel
/// — that one tracks answer ACCURACY per whole GrammarCategory
/// (person/tense/voice/mood/case combined); this one tracks
/// per-individual-VALUE teaching timestamps ("has Aorist specifically
/// been taught, and when"), a different question entirely.
///
/// Generalizes what was originally CaseLessonProgressModel (case-only)
/// to cover all five GrammarCategory dimensions — see project handoff
/// doc's Grammar cluster, item 4.
///
/// One instance per language pair, single blob under a fixed key, in its
/// own Hive box ("grammar_lesson_progress_{pairKey}").
class GrammarLessonProgressModel {
  /// "categoryName:code" -> last time the lesson taught it.
  final Map<String, DateTime> lastTaughtAt;

  const GrammarLessonProgressModel({required this.lastTaughtAt});

  factory GrammarLessonProgressModel.fresh() =>
      const GrammarLessonProgressModel(lastTaughtAt: {});

  /// Due if never taught, or taught 7+ days ago — same fixed weekly
  /// cadence the Cases-lesson pilot used, now shared by every category.
  bool isDue(String key, DateTime now) {
    final last = lastTaughtAt[key];
    if (last == null) return true;
    return now.difference(last).inDays >= 7;
  }

  GrammarLessonProgressModel recordTaught(
    Iterable<String> keys,
    DateTime now,
  ) {
    final updated = Map<String, DateTime>.from(lastTaughtAt);
    for (final key in keys) {
      updated[key] = now;
    }
    return GrammarLessonProgressModel(lastTaughtAt: updated);
  }

  Map<String, dynamic> toMap() => {
        'lastTaughtAt': lastTaughtAt
            .map((key, value) => MapEntry(key, value.toIso8601String())),
      };

  factory GrammarLessonProgressModel.fromMap(Map<dynamic, dynamic> m) {
    final raw = m['lastTaughtAt'] as Map? ?? {};
    return GrammarLessonProgressModel(
      lastTaughtAt: raw.map(
        (key, value) => MapEntry(
          key as String,
          DateTime.tryParse(value as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ),
    );
  }
}