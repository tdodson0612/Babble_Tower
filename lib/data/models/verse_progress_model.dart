// lib/data/models/verse_progress_model.dart

/// Hive-persisted progress for a single verse within a single language
/// pair. Distinct from ReadingProgressModel, which only tracks coarse
/// block-unlock state (a Set<String> of unlocked block keys) — this model
/// captures the data Phase 9's dashboard needs: which words are known,
/// how accurate quiz attempts have been, and how many times the verse
/// has been retried.
///
/// One instance per verse. Stored in its own Hive box
/// ("verse_progress_{pairKey}"), keyed by [verseKey].
class VerseProgressModel {
  /// e.g. "Matthew_1_3" — book_chapter_verseNumber. Matches the same
  /// underscore-joined convention ReadingProgressModel.blockKey uses, so
  /// the two models stay easy to cross-reference even though they're
  /// stored separately.
  final String verseKey;

  /// Greek words in this verse the user currently knows (i.e. had
  /// masteryLevel > 0 / known == true at last quiz completion). Stored as
  /// a snapshot at most-recent-attempt time, not a running total — a word
  /// previously known but since marked unknown again won't linger here.
  final Set<String> knownWords;

  /// Total unique words in this verse, captured at quiz time. Needed
  /// alongside knownWords.length to compute accuracy % without
  /// re-tokenizing the verse text later (verse text isn't stored here).
  final int totalWords;

  /// True once the verse has been passed (>=80%) at least once. Does NOT
  /// reset on a later failed retry — "completed" is sticky, matching how
  /// reader_screen.dart's highestBlock progression already treats a
  /// verse as permanently unlocked once passed.
  final bool completed;

  /// Cumulative count of quiz attempts (pass or fail) for this verse,
  /// across all sessions, forever. Never resets.
  final int retryCount;

  /// Score fraction (0.0–1.0) from the most recent quiz attempt.
  final double lastAccuracy;

  final DateTime lastAttemptAt;

  const VerseProgressModel({
    required this.verseKey,
    required this.knownWords,
    required this.totalWords,
    required this.completed,
    required this.retryCount,
    required this.lastAccuracy,
    required this.lastAttemptAt,
  });

  /// e.g. "Matthew_1_3" — see [verseKey] doc above.
  static String buildKey(String book, int chapter, int verseNumber) =>
      '${book}_${chapter}_$verseNumber';

  double get knownWordFraction =>
      totalWords == 0 ? 0 : knownWords.length / totalWords;

  factory VerseProgressModel.fresh(String verseKey) => VerseProgressModel(
        verseKey: verseKey,
        knownWords: const {},
        totalWords: 0,
        completed: false,
        retryCount: 0,
        lastAccuracy: 0,
        lastAttemptAt: DateTime.now(),
      );

  /// Records a single quiz attempt. [passed] determines whether
  /// [completed] flips true — once true it stays true regardless of
  /// later failed attempts, per the "sticky completion" rule above.
  VerseProgressModel recordAttempt({
    required Set<String> knownWords,
    required int totalWords,
    required bool passed,
    required double accuracy,
  }) {
    return copyWith(
      knownWords: knownWords,
      totalWords: totalWords,
      completed: completed || passed,
      retryCount: retryCount + 1,
      lastAccuracy: accuracy,
      lastAttemptAt: DateTime.now(),
    );
  }

  VerseProgressModel copyWith({
    Set<String>? knownWords,
    int? totalWords,
    bool? completed,
    int? retryCount,
    double? lastAccuracy,
    DateTime? lastAttemptAt,
  }) =>
      VerseProgressModel(
        verseKey: verseKey,
        knownWords: knownWords ?? this.knownWords,
        totalWords: totalWords ?? this.totalWords,
        completed: completed ?? this.completed,
        retryCount: retryCount ?? this.retryCount,
        lastAccuracy: lastAccuracy ?? this.lastAccuracy,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      );

  Map<String, dynamic> toMap() => {
        'verseKey': verseKey,
        'knownWords': knownWords.toList(),
        'totalWords': totalWords,
        'completed': completed,
        'retryCount': retryCount,
        'lastAccuracy': lastAccuracy,
        'lastAttemptAt': lastAttemptAt.toIso8601String(),
      };

  factory VerseProgressModel.fromMap(Map<dynamic, dynamic> m) =>
      VerseProgressModel(
        verseKey: m['verseKey'] as String,
        knownWords: Set<String>.from(
          (m['knownWords'] as List<dynamic>?)?.cast<String>() ?? [],
        ),
        totalWords: m['totalWords'] as int? ?? 0,
        completed: m['completed'] as bool? ?? false,
        retryCount: m['retryCount'] as int? ?? 0,
        lastAccuracy: (m['lastAccuracy'] as num?)?.toDouble() ?? 0,
        lastAttemptAt:
            DateTime.tryParse(m['lastAttemptAt'] as String? ?? '') ??
                DateTime.now(),
      );
}