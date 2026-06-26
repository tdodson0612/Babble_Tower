// lib/presentation/providers/bible_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/bible_service.dart';
import '../../core/constants/supported_languages.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/verse_block.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class BibleState {
  final List<String> availableBooks;
  final String? selectedBook;
  final int? selectedChapter;
  final int selectedBookChapterCount;
  final List<Verse> verses;
  final List<VerseBlock> blocks;
  final int currentBlockIndex;
  final bool isLoading;
  final String? error;

  const BibleState({
    this.availableBooks = const [],
    this.selectedBook,
    this.selectedChapter,
    this.selectedBookChapterCount = 0,
    this.verses = const [],
    this.blocks = const [],
    this.currentBlockIndex = 0,
    this.isLoading = false,
    this.error,
  });

  VerseBlock? get currentBlock =>
      blocks.isNotEmpty && currentBlockIndex < blocks.length
          ? blocks[currentBlockIndex]
          : null;

  bool get hasNextBlock => currentBlockIndex < blocks.length - 1;
  bool get hasPrevBlock => currentBlockIndex > 0;

  BibleState copyWith({
    List<String>? availableBooks,
    String? selectedBook,
    int? selectedChapter,
    int? selectedBookChapterCount,
    List<Verse>? verses,
    List<VerseBlock>? blocks,
    int? currentBlockIndex,
    bool? isLoading,
    Object? error = _keep,          // sentinel: omit to preserve existing error
  }) =>
      BibleState(
        availableBooks: availableBooks ?? this.availableBooks,
        selectedBook: selectedBook ?? this.selectedBook,
        selectedChapter: selectedChapter ?? this.selectedChapter,
        selectedBookChapterCount:
            selectedBookChapterCount ?? this.selectedBookChapterCount,
        verses: verses ?? this.verses,
        blocks: blocks ?? this.blocks,
        currentBlockIndex: currentBlockIndex ?? this.currentBlockIndex,
        isLoading: isLoading ?? this.isLoading,
        error: error == _keep ? this.error : error as String?,
      );
}

// Sentinel value so copyWith can distinguish "clear error" from "leave error alone"
const Object _keep = Object();

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Babble Tower now reads a single fixed language: Koine Greek.
/// reloadForLanguage() and the languageProvider dependency are gone —
/// there is nothing left to switch between.
class BibleNotifier extends StateNotifier<BibleState> {
  BibleNotifier(this._service) : super(const BibleState()) {
    _init();
  }

  final BibleService _service;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final books = await _service.getAvailableBooks(AppLanguage.targetCode);
      state = state.copyWith(availableBooks: books, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load book list: $e',
      );
    }
  }

  /// Called when user taps a book — loads chapter count into state immediately.
  Future<void> selectBook(String book) async {
    state = state.copyWith(
      selectedBook: book,
      selectedChapter: null,
      selectedBookChapterCount: 0,
      isLoading: true,
    );
    try {
      final count =
          await _service.getChapterCount(AppLanguage.targetCode, book);
      state = state.copyWith(
        selectedBookChapterCount: count,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load chapters for $book: $e',
      );
    }
  }

  /// Loads all verses for [book] + [chapter], builds blocks.
  Future<void> loadChapter(String book, int chapter) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final verses =
          await _service.getVerses(AppLanguage.targetCode, book, chapter);
      final blocks = _service.buildBlocks(verses);
      state = state.copyWith(
        selectedBook: book,
        selectedChapter: chapter,
        verses: verses,
        blocks: blocks,
        currentBlockIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load chapter: $e',
      );
    }
  }

  void nextBlock() {
    if (state.hasNextBlock) {
      state = state.copyWith(currentBlockIndex: state.currentBlockIndex + 1);
    }
  }

  void prevBlock() {
    if (state.hasPrevBlock) {
      state = state.copyWith(currentBlockIndex: state.currentBlockIndex - 1);
    }
  }

  void goToBlock(int index) {
    if (index >= 0 && index < state.blocks.length) {
      state = state.copyWith(currentBlockIndex: index);
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final bibleServiceProvider = Provider<BibleService>((_) => BibleService());

final bibleProvider = StateNotifierProvider<BibleNotifier, BibleState>((ref) {
  return BibleNotifier(ref.read(bibleServiceProvider));
});