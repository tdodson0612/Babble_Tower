// lib/presentation/widgets/tappable_word.dart
//
// RECONSTRUCTED, NOT RECOVERED. The original file was accidentally
// deleted from disk and was never committed to git, so nothing of the
// literal original survives anywhere I have access to. This is a
// best-effort rebuild from: (a) how verse_block_view.dart actually
// calls this widget (rawToken/isKnown/textScale/lemma), and (b) this
// project's own handoff notes describing its behavior — a tap opens a
// detail view showing the word's translation and BOTH pronunciation
// forms (Modern Greek with audio, Koine as text-only display — see
// pronunciation_service.dart's own doc comment for why Koine has no
// audio), plus "✓ Got it" / "✗ Not yet" buttons that mark the word
// known/unknown.
//
// DELIBERATELY OMITTED: the Word Family section. Past notes mention
// TappableWord showing one when [lemma] is non-null, but I don't have
// word_family_service.dart's or word_family.dart's real API, and
// guessing at method names here risked introducing a second wave of
// compile errors during an already-stressful recovery. Paste both of
// those files and I'll add the section back correctly rather than
// guessing.
//
// Exact spacing/colors/layout will likely differ from what you had
// before, even though the core behavior should match.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supported_languages.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/services/dictionary_service.dart';
import '../../data/services/pronunciation_service.dart';
import '../providers/vocabulary_provider.dart';

class TappableWord extends StatelessWidget {
  final String rawToken;
  final bool isKnown;
  final double textScale;
  final String? lemma;

  const TappableWord({
    super.key,
    required this.rawToken,
    required this.isKnown,
    required this.textScale,
    this.lemma,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: () => _showDetail(context),
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
      builder: (_) => _WordDetailSheet(rawToken: rawToken, lemma: lemma),
    );
  }
}

class _WordDetailSheet extends ConsumerStatefulWidget {
  final String rawToken;
  final String? lemma;

  const _WordDetailSheet({required this.rawToken, required this.lemma});

  @override
  ConsumerState<_WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends ConsumerState<_WordDetailSheet> {
  // ignore: prefer_const_constructors
  static final _dictionary = DictionaryService();
  // ignore: prefer_const_constructors
  static final _pronunciation = PronunciationService();

  late final String _normalized;
  String? _translation;
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
    if (!mounted) return;
    setState(() {
      _translation = entry?.gloss;
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
            else
              Text(
                (_translation?.isNotEmpty ?? false)
                    ? _translation!
                    : 'No translation found',
                style: TextStyle(fontSize: 16, color: colors.textPrimary),
              ),

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