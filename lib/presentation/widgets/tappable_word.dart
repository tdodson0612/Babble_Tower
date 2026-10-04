// lib/presentation/widgets/tappable_word.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supported_languages.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/services/dictionary_service.dart';
import '../../data/services/kjv_alignment_service.dart';
import '../../data/services/pronunciation_service.dart';
import '../../data/services/word_family_service.dart';
import '../../domain/entities/word_family.dart';
import '../providers/vocabulary_provider.dart';

class TappableWord extends StatelessWidget {
  final String rawToken;
  final bool isKnown;
  final double textScale;
  final String? lemma;
  final String? book;
  final String? chapter;
  final int? verseNumber;
  final int? wordIndex;

  const TappableWord({
    super.key,
    required this.rawToken,
    required this.isKnown,
    required this.textScale,
    this.lemma,
    this.book,
    this.chapter,
    this.verseNumber,
    this.wordIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Text(
          rawToken,
          style: TextStyle(
            fontSize: 17 * textScale,
            color: isKnown ? colors.primary : colors.textPrimary,
            fontWeight: isKnown ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WordDetailSheet(
        rawToken: rawToken,
        lemma: lemma,
        book: book,
        chapter: chapter,
        verseNumber: verseNumber,
        wordIndex: wordIndex,
      ),
    );
  }
}

class WordDetailSheet extends ConsumerStatefulWidget {
  final String rawToken;
  final String? lemma;
  final String? book;
  final String? chapter;
  final int? verseNumber;
  final int? wordIndex;

  const WordDetailSheet({
    super.key,
    required this.rawToken,
    required this.lemma,
    this.book,
    this.chapter,
    this.verseNumber,
    this.wordIndex,
  });

  @override
  ConsumerState<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends ConsumerState<WordDetailSheet> {
  // ignore: prefer_const_constructors
  static final _dictionary = DictionaryService();
  // ignore: prefer_const_constructors
  static final _pronunciation = PronunciationService();
  static final _kjvAlignment = KjvAlignmentService();
  static final _wordFamily = WordFamilyService();

  late final String _normalized;
  String? _translation;
  String _kjvRendering = '';
  WordFamily? _family;
  bool _loading = true;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _normalized = TextNormalizer.normalizeWord(widget.rawToken);
    _load();
  }

  Future<void> _load() async {
    final entry = await _dictionary.lookup(
      AppLanguage.readingDictionaryKey, // 'el_en' — never pairKey here
      _normalized,
    );

    // Per-occurrence KJV rendering — a SECOND, complementary gloss
    // alongside the dictionary's single shared gloss above. Only
    // available when this widget was given its verse location (book/
    // chapter/verseNumber/wordIndex all non-null); silently absent
    // otherwise rather than erroring, since this is a supplementary
    // feature, not core functionality.
    String kjv = '';
    if (widget.book != null &&
        widget.chapter != null &&
        widget.verseNumber != null &&
        widget.wordIndex != null) {
      kjv = await _kjvAlignment.forWord(
        widget.book!,
        widget.chapter!,
        widget.verseNumber!,
        widget.wordIndex!,
      );
    }

    // Word family (root/cognate relations) — only resolvable when we
    // have a real lemma from morphology data; WordEntry.lemma is
    // always empty, so widget.lemma is the only reliable source (see
    // WordFamilyService's own doc comment).
    WordFamily? family;
    if (widget.lemma != null && widget.lemma!.isNotEmpty) {
      family = await _wordFamily.lookup(widget.lemma!);
    }

    if (!mounted) return;
    setState(() {
      _translation = entry?.gloss;
      _kjvRendering = kjv;
      _family = family;
      _loading = false;
    });
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _pronunciation.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await _pronunciation.speak(widget.rawToken);
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _mark(bool known) async {
    final notifier = ref.read(vocabularyProvider.notifier);
    if (known) {
      await notifier.markKnown(_normalized);
    } else {
      await notifier.markUnknown(_normalized);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Combines the dictionary translation with the per-occurrence KJV
  /// rendering into ONE displayed string, matching the same merge rule
  /// used in verse_block_view.dart's "Show translation" row — no
  /// separate "KJV:" label, just an extra comma-separated item, and
  /// skipped if it's empty or already effectively present in the
  /// dictionary translation.
  String _mergedTranslationDisplay() {
    final translation = _translation;
    if (translation == null || translation.isEmpty) {
      return _kjvRendering.isNotEmpty ? _kjvRendering : 'No translation found';
    }
    if (_kjvRendering.isEmpty) return translation;
    final alreadyPresent =
        translation.toLowerCase().contains(_kjvRendering.toLowerCase());
    if (alreadyPresent) return translation;
    return '$translation, or $_kjvRendering';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pair = _pronunciation.getPair(widget.rawToken);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.rawToken,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // Modern Greek — has real audio.
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleSpeak,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _speaking
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.highlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                      size: 16,
                      color: _speaking ? colors.primary : colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Modern: ${pair.modernGreek}',
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Koine — text-only display spelling, deliberately no
            // audio button. See pronunciation_service.dart's class doc
            // for why: Koine-specific TTS was tried this project and
            // explicitly rolled back after real testing.
            Text(
              'Koine: ${pair.koineGreek}',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 18),
            Divider(color: colors.border),
            const SizedBox(height: 18),

            if (_loading)
              Center(
                child: CircularProgressIndicator(color: colors.primary),
              )
            else ...[
              Text(
                _mergedTranslationDisplay(),
                style: TextStyle(fontSize: 16, color: colors.textPrimary),
              ),

              // Word Family section — root/cognate relations, only
              // shown when this word resolved to a real lemma AND that
              // lemma has recorded relations in the lexicon. See
              // WordFamilyService's class doc for why this sometimes
              // legitimately shows nothing even for a resolvable lemma
              // (isolated roots, or genuine MorphGNT/Strong's citation
              // spelling disagreements).
              if (_family != null && _family!.hasRelations) ...[
                const SizedBox(height: 18),
                Divider(color: colors.border),
                const SizedBox(height: 18),
                Text(
                  'Word Family',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_family!.lemma} — ${_family!.gloss}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (_family!.derivesFrom.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'From: ${_family!.derivesFrom.join(', ')}',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
                if (_family!.derivedForms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Related: ${_family!.derivedForms.join(', ')}',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ],
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _mark(false),
                    child: Text(
                      '✗ Not yet',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _mark(true),
                    child: const Text('✓ Got it'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}