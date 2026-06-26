// lib/data/models/word_entry_model.dart

/// Hive-persisted model for a single vocabulary word.
/// Mirrors the domain WordEntry entity but is storage-oriented.
class WordEntryModel {
  final String word;
  final String languagePairKey; // e.g. "en_es"
  final String translation;
  final bool known;
  final int masteryLevel;       // 0–3
  final DateTime lastReviewed;

  const WordEntryModel({
    required this.word,
    required this.languagePairKey,
    required this.translation,
    required this.known,
    required this.masteryLevel,
    required this.lastReviewed,
  });

  WordEntryModel copyWith({
    String? translation,
    bool? known,
    int? masteryLevel,
    DateTime? lastReviewed,
  }) =>
      WordEntryModel(
        word: word,
        languagePairKey: languagePairKey,
        translation: translation ?? this.translation,
        known: known ?? this.known,
        masteryLevel:
            (masteryLevel ?? this.masteryLevel).clamp(0, 3),
        lastReviewed: lastReviewed ?? this.lastReviewed,
      );

  Map<String, dynamic> toMap() => {
        'word': word,
        'languagePairKey': languagePairKey,
        'translation': translation,
        'known': known,
        'masteryLevel': masteryLevel,
        'lastReviewed': lastReviewed.toIso8601String(),
      };

  factory WordEntryModel.fromMap(Map<dynamic, dynamic> m) =>
      WordEntryModel(
        word: m['word'] as String,
        languagePairKey: m['languagePairKey'] as String,
        translation: m['translation'] as String? ?? '',
        known: m['known'] as bool? ?? false,
        masteryLevel: m['masteryLevel'] as int? ?? 0,
        lastReviewed: DateTime.tryParse(
                m['lastReviewed'] as String? ?? '') ??
            DateTime.now(),
      );

  /// Creates a brand-new unseen entry.
  factory WordEntryModel.unseen({
    required String word,
    required String languagePairKey,
  }) =>
      WordEntryModel(
        word: word,
        languagePairKey: languagePairKey,
        translation: '',
        known: false,
        masteryLevel: 0,
        lastReviewed: DateTime.now(),
      );
}