// lib/presentation/widgets/tappable_word.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/services/pronunciation_service.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/word_family_service.dart';
import '../../domain/entities/pronunciation_pair.dart';
import '../../domain/entities/word_family.dart';
import '../providers/vocabulary_provider.dart';
import '../providers/settings_provider.dart';

/// Renders a single word that can be tapped to reveal its translation.
/// Shows a bottom sheet with translation, pronunciation comparison panel,
/// mark-known controls, and (Phase 12, when available) a word-family
/// section showing root/cognate relationships.
class TappableWord extends ConsumerWidget {
  final String rawToken;
  final bool isKnown;
  final double textScale;

  /// Phase 12 — this word's citation lemma, if known. Always null unless
  /// the containing verse had aligned morphology data (see Phase 10's
  /// build_morphology.py) AND this specific token was in it. Null simply
  /// means the word-family section doesn't appear — this is the ONLY
  /// reliable lemma source in the app; WordEntry.lemma is always empty
  /// (el_en.json has no lemma data).
  final String? lemma;

  const TappableWord({
    super.key,
    required this.rawToken,
    this.isKnown = false,
    this.textScale = 1.0,
    this.lemma,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors     = context.colors;
    final normalized = TextNormalizer.normalizeWord(rawToken);
    final entry      = ref.watch(
      vocabularyProvider.select((s) => s.entries[normalized]),
    );
    final haptic = ref.watch(
      settingsProvider.select((s) => s.hapticFeedback),
    );

    return GestureDetector(
      onTap: () {
        if (haptic) HapticFeedback.lightImpact();
        _showTranslationSheet(context, ref, normalized, entry?.translation);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        decoration: isKnown
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              )
            : null,
        child: Text(
          rawToken,
          style: TextStyle(
            fontSize: 18 * textScale,
            height: 1.8,
            color:      isKnown ? colors.primary : colors.textPrimary,
            fontWeight: isKnown ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showTranslationSheet(
    BuildContext context,
    WidgetRef ref,
    String word,
    String? translation,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TranslationSheet(
        word:        word,
        translation: translation,
        lemma:       lemma,
        onMarkKnown:   () => ref.read(vocabularyProvider.notifier).markKnown(word),
        onMarkUnknown: () => ref.read(vocabularyProvider.notifier).markUnknown(word),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Translation bottom sheet
// ---------------------------------------------------------------------------

class _TranslationSheet extends StatefulWidget {
  final String  word;
  final String? translation;
  final String? lemma;
  final VoidCallback onMarkKnown;
  final VoidCallback onMarkUnknown;

  const _TranslationSheet({
    required this.word,
    required this.translation,
    required this.lemma,
    required this.onMarkKnown,
    required this.onMarkUnknown,
  });

  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet> {
  static const _pronunciation = PronunciationService();
  late final PronunciationPair _pair;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _pair = _pronunciation.getPair(widget.word);
  }

  /// The panel's one play button — genuine Modern Greek voice (el-GR),
  /// raw Greek text. Subject to the "no Greek voice installed" known
  /// limitation — see tts_service.dart's class doc. There used to be a
  /// second, independent play button on the Koine row too, but that
  /// pathway (PronunciationService.speakKoine) no longer plays distinct
  /// audio — it's just an alias for this same call now, after this
  /// session's pronunciation-system rollback (see PronunciationService's
  /// class doc) — so a second button would have been misleading: two
  /// controls implying two different sounds, playing the identical
  /// thing. Removed rather than kept for symmetry.
  Future<void> _toggleSpeech() async {
    if (_speaking) {
      await _pronunciation.stop();
      setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await _pronunciation.speak(widget.word);
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
            // Handle
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

            // Word + speaker button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.word,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleSpeech,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _speaking
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.highlight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _speaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      color: _speaking
                          ? colors.primary
                          : colors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Translation
            Text(
              widget.translation?.isNotEmpty == true
                  ? widget.translation!
                  : 'No translation saved yet.',
              style: TextStyle(
                fontSize: 18,
                color: widget.translation?.isNotEmpty == true
                    ? colors.accent
                    : colors.textSecondary,
                fontStyle: widget.translation?.isNotEmpty == true
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),

            // ── Pronunciation comparison panel ─────────────────────────
            // Shows Modern Greek and Koine phonetic spellings side by
            // side. Only the Modern Greek row has a play button — see
            // _toggleSpeech's doc for why the Koine row's button was
            // removed rather than kept.
            _PronunciationPanel(
              pair:     _pair,
              speaking: _speaking,
              onTap:    _toggleSpeech,
              colors:   colors,
            ),

            // ── Word family section (Phase 12) ──────────────────────────
            // Only rendered when a lemma was resolved AND that lemma has
            // recorded family data. Renders nothing (not even a loading
            // spinner) otherwise — this is a bonus section, not core
            // content the sheet should ever appear to be waiting on.
            if (widget.lemma != null && widget.lemma!.isNotEmpty)
              _WordFamilySection(lemma: widget.lemma!, colors: colors),

            const SizedBox(height: 20),

            // Action row
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label:   '✓  I know this',
                    primary: true,
                    onTap: () {
                      widget.onMarkKnown();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetButton(
                    label:   '✗  Not yet',
                    primary: false,
                    onTap: () {
                      widget.onMarkUnknown();
                      Navigator.of(context).pop();
                    },
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

// ---------------------------------------------------------------------------
// Word family section (Phase 12)
// ---------------------------------------------------------------------------

class _FamilyDisplayData {
  final WordFamily family;
  final Map<String, String> glosses; // related lemma -> its own gloss
  const _FamilyDisplayData({required this.family, required this.glosses});
}

class _WordFamilySection extends StatefulWidget {
  final String lemma;
  final AppColors colors;

  const _WordFamilySection({required this.lemma, required this.colors});

  @override
  State<_WordFamilySection> createState() => _WordFamilySectionState();
}

class _WordFamilySectionState extends State<_WordFamilySection> {
  static final _service = WordFamilyService();
  late final Future<_FamilyDisplayData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FamilyDisplayData?> _load() async {
    final family = await _service.lookup(widget.lemma);
    if (family == null || !family.hasRelations) return null;

    // Every related lemma is guaranteed to have its own lexicon entry
    // (it must, to be listed as a relation of this one — see
    // build_word_families.py's inversion step), so this is safe. The
    // whole lexicon is already cached in memory after the first lookup
    // above, so these are cheap.
    final glosses = <String, String>{};
    for (final related in [...family.derivesFrom, ...family.derivedForms]) {
      final relatedFamily = await _service.lookup(related);
      if (relatedFamily != null) glosses[related] = relatedFamily.gloss;
    }
    return _FamilyDisplayData(family: family, glosses: glosses);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FamilyDisplayData?>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.colors.highlight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Word Family',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.colors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
                if (data.family.derivesFrom.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Derives from',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.colors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._relationRows(data.family.derivesFrom, data.glosses),
                ],
                if (data.family.derivedForms.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Related words',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.colors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._relationRows(data.family.derivedForms, data.glosses),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _relationRows(List<String> lemmas, Map<String, String> glosses) {
    return lemmas.map((lemma) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lemma,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                glosses[lemma] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Pronunciation comparison panel
// ---------------------------------------------------------------------------

class _PronunciationPanel extends StatelessWidget {
  final PronunciationPair pair;
  final bool speaking;
  final VoidCallback onTap;
  final AppColors colors;

  const _PronunciationPanel({
    required this.pair,
    required this.speaking,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.highlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // Modern Greek row — the only row with a play button, since
          // it's the only pathway with real, distinct audio.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.volume_up_rounded,
                              size: 13, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Modern Greek (TTS)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pair.modernDisplay.isNotEmpty
                            ? pair.modernDisplay
                            : '—',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Play button inline in the panel
                GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: speaking
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      speaking
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                      color: speaking
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colors.border),

          // Koine row — text-only. There is no distinct Koine audio
          // pathway anymore (see PronunciationService's class doc for
          // the full story): PronunciationService.speakKoine is now
          // just an alias for the same Modern Greek audio the row
          // above already plays. A second, independent play button
          // here would visually promise a different sound than what
          // actually plays — removed rather than kept for symmetry
          // with the row above.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koine Pronunciation',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pair.koineDisplay.isNotEmpty ? pair.koineDisplay : '—',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet button
// ---------------------------------------------------------------------------

class _SheetButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:  primary ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? colors.primary : colors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primary ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}