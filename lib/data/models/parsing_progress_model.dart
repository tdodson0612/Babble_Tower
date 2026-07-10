// lib/data/models/parsing_progress_model.dart

/// Per-category accuracy for grammar-parsing quiz questions (Phase 10).
/// Distinct from VerseProgressModel (per-verse vocabulary knowledge) and
/// ReadingProgressModel (coarse block-unlock state) — this tracks a
/// completely separate skill: "can the user correctly identify case,
/// tense, voice, mood, and person", aggregated across every verse
/// they've ever parsed, not scoped to one verse.
///
/// One instance per language pair, stored as a single blob under a fixed
/// key ("aggregate") in its own Hive box
/// ("parsing_progress_{pairKey}") — see HiveService.parsingProgressBoxName.
/// Aggregate rather than per-verse because the dashboard question this
/// answers is "am I getting better at recognizing genitive case", not
/// "did I parse Matthew 1:3 correctly".
class ParsingProgressModel {
  /// category name (GrammarCategory.name, e.g. "tense", "grammaticalCase")
  /// -> {correct, total} counts, cumulative forever.
  final Map<String, ParsingCategoryStats> byCategory;

  const ParsingProgressModel({required this.byCategory});

  factory ParsingProgressModel.fresh() =>
      const ParsingProgressModel(byCategory: {});

  /// Overall accuracy across every category combined.
  double get overallAccuracy {
    var correct = 0;
    var total = 0;
    for (final stats in byCategory.values) {
      correct += stats.correct;
      total += stats.total;
    }
    return total == 0 ? 0 : correct / total;
  }

  /// Records one answered grammar-parsing question. [categoryName] is
  /// GrammarCategory.name from parsing_word.dart — kept as a plain
  /// String here (rather than importing the domain enum into the data
  /// layer) to respect the data -> domain -> presentation direction:
  /// data models must not depend on domain entities.
  ParsingProgressModel recordAnswer(String categoryName, bool correct) {
    final current = byCategory[categoryName] ??
        const ParsingCategoryStats(correct: 0, total: 0);
    final updated = ParsingCategoryStats(
      correct: current.correct + (correct ? 1 : 0),
      total: current.total + 1,
    );
    return ParsingProgressModel(
      byCategory: {...byCategory, categoryName: updated},
    );
  }

  Map<String, dynamic> toMap() => {
        'byCategory': byCategory
            .map((key, stats) => MapEntry(key, stats.toMap())),
      };

  factory ParsingProgressModel.fromMap(Map<dynamic, dynamic> m) {
    final raw = m['byCategory'] as Map? ?? {};
    return ParsingProgressModel(
      byCategory: raw.map(
        (key, value) => MapEntry(
          key as String,
          ParsingCategoryStats.fromMap(value as Map),
        ),
      ),
    );
  }
}

class ParsingCategoryStats {
  final int correct;
  final int total;

  const ParsingCategoryStats({required this.correct, required this.total});

  double get accuracy => total == 0 ? 0 : correct / total;

  Map<String, dynamic> toMap() => {'correct': correct, 'total': total};

  factory ParsingCategoryStats.fromMap(Map<dynamic, dynamic> m) =>
      ParsingCategoryStats(
        correct: m['correct'] as int? ?? 0,
        total: m['total'] as int? ?? 0,
      );
}