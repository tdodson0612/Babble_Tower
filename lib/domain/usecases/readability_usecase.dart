// lib/domain/usecases/readability_usecase.dart

import '../../data/services/vocabulary_service.dart';
import '../../domain/entities/word_entry.dart';
import '../../core/constants/supported_languages.dart';

/// Readability categories — how much of a verse a user can read
/// based on their current known-word set.
enum ReadabilityLevel {
  /// 100% of unique words are known.
  fully,

  /// 80–99% of unique words are known.
  mostly,

  /// 50–79% of unique words are known.
  partially,

  /// <50% of unique words are known.
  notYet,
}

extension ReadabilityLevelX on ReadabilityLevel {
  String get label {
    switch (this) {
      case ReadabilityLevel.fully:     return 'Fully readable';
      case ReadabilityLevel.mostly:    return 'Mostly readable';
      case ReadabilityLevel.partially: return 'Partially readable';
      case ReadabilityLevel.notYet:    return 'Not yet readable';
    }
  }

  static ReadabilityLevel fromFraction(double f) {
    if (f >= 1.0) return ReadabilityLevel.fully;
    if (f >= 0.8) return ReadabilityLevel.mostly;
    if (f >= 0.5) return ReadabilityLevel.partially;
    return ReadabilityLevel.notYet;
  }
}

/// Readability result for a single verse.
class VerseReadability {
  final String book;
  final int chapter;
  final int verseNumber;
  final int knownWords;
  final int totalWords;
  final ReadabilityLevel level;

  const VerseReadability({
    required this.book,
    required this.chapter,
    required this.verseNumber,
    required this.knownWords,
    required this.totalWords,
    required this.level,
  });

  double get fraction =>
      totalWords == 0 ? 0 : knownWords / totalWords;
}

/// Aggregated readability stats for one Gospel (book).
class BookReadability {
  final String book;
  final int totalVerses;
  final int fullyReadable;
  final int mostlyReadable;
  final int partiallyReadable;
  final int notYetReadable;
  final List<VerseReadability> verses;

  const BookReadability({
    required this.book,
    required this.totalVerses,
    required this.fullyReadable,
    required this.mostlyReadable,
    required this.partiallyReadable,
    required this.notYetReadable,
    required this.verses,
  });

  double get readableFraction {
    if (totalVerses == 0) return 0;
    return (fullyReadable + mostlyReadable) / totalVerses;
  }
}

/// Computes readability across all known verses using the current
/// vocabulary state. Informational only — does not affect the quiz-gate
/// unlock mechanism (see reader_screen.dart and TrackProgressUseCase).
///
/// Strategy:
///   1. Load all known words from Hive via VocabularyService.
///   2. For each verse in [verseWordMap], compute known/total fraction.
///   3. Categorize using ReadabilityLevel thresholds.
///   4. Aggregate per book.
///
/// [verseWordMap] is provided by the caller (typically a FutureProvider
/// in the UI layer) since BibleService is async and this use case stays
/// free of Flutter/widget dependencies.
class ReadabilityUseCase {
  const ReadabilityUseCase();

  /// Returns per-book readability stats.
  ///
  /// [verseWordMap] — map of "book_chapter_verse" → List<String> of
  /// unique normalized words extracted from that verse. The caller builds
  /// this from BibleService.getVerses + TextNormalizer.extractWords.
  Future<List<BookReadability>> compute({
    required Map<String, List<String>> verseWordMap,
    required Map<String, String> verseToBook,
    required Map<String, int> verseToChapter,
    required Map<String, int> verseToNumber,
  }) async {
    // Load known words once — single Hive read for the whole computation.
    final vocab = VocabularyService();
    final allEntries = await vocab.getAll(AppLanguage.pairKey);
    final knownSet = allEntries
        .where((e) => e.known)
        .map((e) => e.word)
        .toSet();

    // Compute per-verse readability.
    final verseResults = <VerseReadability>[];
    for (final entry in verseWordMap.entries) {
      final key         = entry.key;
      final words       = entry.value;
      final totalWords  = words.length;
      final knownCount  = words.where((w) => knownSet.contains(w)).length;
      final fraction    = totalWords == 0 ? 0.0 : knownCount / totalWords;
      final level       = ReadabilityLevelX.fromFraction(fraction);

      verseResults.add(VerseReadability(
        book:        verseToBook[key]    ?? '',
        chapter:     verseToChapter[key] ?? 0,
        verseNumber: verseToNumber[key]  ?? 0,
        knownWords:  knownCount,
        totalWords:  totalWords,
        level:       level,
      ));
    }

    // Aggregate by book.
    final byBook = <String, List<VerseReadability>>{};
    for (final v in verseResults) {
      byBook.putIfAbsent(v.book, () => []).add(v);
    }

    return byBook.entries.map((e) {
      final verses  = e.value;
      return BookReadability(
        book:               e.key,
        totalVerses:        verses.length,
        fullyReadable:      verses.where((v) => v.level == ReadabilityLevel.fully).length,
        mostlyReadable:     verses.where((v) => v.level == ReadabilityLevel.mostly).length,
        partiallyReadable:  verses.where((v) => v.level == ReadabilityLevel.partially).length,
        notYetReadable:     verses.where((v) => v.level == ReadabilityLevel.notYet).length,
        verses:             verses..sort((a, b) {
          final chap = a.chapter.compareTo(b.chapter);
          return chap != 0 ? chap : a.verseNumber.compareTo(b.verseNumber);
        }),
      );
    }).toList()
      ..sort((a, b) => a.book.compareTo(b.book));
  }
}