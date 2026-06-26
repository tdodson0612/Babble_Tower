// lib/data/models/reading_progress_model.dart

/// Hive-persisted reading progress for a user.
/// Tracks which book/chapter/block the user last reached
/// and which blocks have been fully unlocked.
class ReadingProgressModel {
  final String languagePairKey;   // e.g. "en_es"
  final String book;
  final int chapter;
  final int blockIndex;
  final Set<String> unlockedBlocks; // "book_chapter_blockIndex"
  final DateTime lastReadAt;

  const ReadingProgressModel({
    required this.languagePairKey,
    required this.book,
    required this.chapter,
    required this.blockIndex,
    required this.unlockedBlocks,
    required this.lastReadAt,
  });

  /// Composite key used as the Hive box key.
  String get key => languagePairKey;

  /// Generates a block identifier string.
  static String blockKey(String book, int chapter, int blockIndex) =>
      '${book}_${chapter}_$blockIndex';

  bool isBlockUnlocked(String book, int chapter, int blockIndex) =>
      unlockedBlocks.contains(blockKey(book, chapter, blockIndex));

  ReadingProgressModel unlockBlock(
          String book, int chapter, int blockIndex) =>
      copyWith(
        unlockedBlocks: {
          ...unlockedBlocks,
          blockKey(book, chapter, blockIndex),
        },
      );

  ReadingProgressModel copyWith({
    String? book,
    int? chapter,
    int? blockIndex,
    Set<String>? unlockedBlocks,
    DateTime? lastReadAt,
  }) =>
      ReadingProgressModel(
        languagePairKey: languagePairKey,
        book: book ?? this.book,
        chapter: chapter ?? this.chapter,
        blockIndex: blockIndex ?? this.blockIndex,
        unlockedBlocks: unlockedBlocks ?? this.unlockedBlocks,
        lastReadAt: lastReadAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'languagePairKey': languagePairKey,
        'book': book,
        'chapter': chapter,
        'blockIndex': blockIndex,
        'unlockedBlocks': unlockedBlocks.toList(),
        'lastReadAt': lastReadAt.toIso8601String(),
      };

  factory ReadingProgressModel.fromMap(Map<dynamic, dynamic> m) =>
      ReadingProgressModel(
        languagePairKey: m['languagePairKey'] as String,
        book: m['book'] as String? ?? 'John',
        chapter: m['chapter'] as int? ?? 1,
        blockIndex: m['blockIndex'] as int? ?? 0,
        unlockedBlocks: Set<String>.from(
          (m['unlockedBlocks'] as List<dynamic>?)
                  ?.cast<String>() ??
              [],
        ),
        lastReadAt: DateTime.tryParse(
                m['lastReadAt'] as String? ?? '') ??
            DateTime.now(),
      );

  factory ReadingProgressModel.fresh(String pairKey) =>
      ReadingProgressModel(
        languagePairKey: pairKey,
        book: 'John',
        chapter: 1,
        blockIndex: 0,
        unlockedBlocks: const {},
        lastReadAt: DateTime.now(),
      );
}