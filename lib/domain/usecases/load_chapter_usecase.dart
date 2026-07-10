// lib/domain/usecases/load_chapter_usecase.dart

import '../entities/verse.dart';
import '../entities/verse_block.dart';
import '../../data/services/bible_service.dart';

/// Loads a full chapter and splits it into verse blocks (one verse per
/// block — see BibleService.buildBlocks, blockSize=1). This is the single
/// entry point for all chapter loading logic.
class LoadChapterUseCase {
  final BibleService _bibleService;

  const LoadChapterUseCase(this._bibleService);

  Future<LoadChapterResult> call({
    required String languageCode,
    required String book,
    required int chapter,
  }) async {
    try {
      final verses = await _bibleService.getVerses(
        languageCode,
        book,
        chapter,
      );

      if (verses.isEmpty) {
        return LoadChapterResult.failure(
          'No verses found for $book $chapter in $languageCode.',
        );
      }

      final blocks = _bibleService.buildBlocks(verses);

      return LoadChapterResult.success(
        verses: verses,
        blocks: blocks,
        book: book,
        chapter: chapter,
        languageCode: languageCode,
      );
    } catch (e) {
      return LoadChapterResult.failure(
        'Failed to load $book $chapter: $e',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class LoadChapterResult {
  final bool success;
  final List<Verse> verses;
  final List<VerseBlock> blocks;
  final String book;
  final int chapter;
  final String languageCode;
  final String? errorMessage;

  const LoadChapterResult._({
    required this.success,
    required this.verses,
    required this.blocks,
    required this.book,
    required this.chapter,
    required this.languageCode,
    this.errorMessage,
  });

  factory LoadChapterResult.success({
    required List<Verse> verses,
    required List<VerseBlock> blocks,
    required String book,
    required int chapter,
    required String languageCode,
  }) =>
      LoadChapterResult._(
        success: true,
        verses: verses,
        blocks: blocks,
        book: book,
        chapter: chapter,
        languageCode: languageCode,
      );

  factory LoadChapterResult.failure(String message) => LoadChapterResult._(
        success: false,
        verses: const [],
        blocks: const [],
        book: '',
        chapter: 0,
        languageCode: '',
        errorMessage: message,
      );
}