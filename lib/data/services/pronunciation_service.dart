// lib/data/services/pronunciation_service.dart

import '../../domain/entities/pronunciation_pair.dart';
import 'koine_phonetic_service.dart';
import 'tts_service.dart';

/// Facade combining Modern Greek TTS and Koine phonetic reconstruction.
///
/// Single call site for all pronunciation needs in the app:
///   - [getPair] returns a PronunciationPair for display — the Koine
///     side is still a real, distinct phonetic spelling
///     (KoinePhoneticService.generateKoinePhonetic), unaffected by the
///     decision below. Only AUDIO was simplified, not the on-screen
///     text.
///   - [speak] plays Modern Greek audio via TtsService.
///   - [speakKoine] — after evaluating a genuine Modern-Greek-voice
///     cloud path (Koine text respelled η→ε, fed to Google Cloud TTS)
///     against a real problem word (γενέσεως's "-εως" ending came out
///     wrong — NT Greek's literary/archaic word-forms are underrepresented
///     in the modern-colloquial text neural voices are trained on) and
///     the on-device English-voice approximation (never sounded like
///     real Greek to begin with), the decision was made to stop
///     chasing a distinct "Koine-sounding" audio pronunciation
///     altogether. [speakKoine] now simply plays authentic Modern Greek
///     audio, same as [speak] — kept as a separate method (rather than
///     deleted) so existing call sites elsewhere in the app that expect
///     a speakKoine() method keep compiling without needing to be
///     hunted down and edited individually.
class PronunciationService {
  const PronunciationService();

  static const _koine = KoinePhoneticService();

  // Matches any character that is NOT a Greek letter or combining
  // diacritic -- i.e. punctuation, digits, whitespace, or anything
  // else that shouldn't appear in a pronunciation string. Same
  // Unicode ranges as TextNormalizer's stripper, but tighter (no
  // Latin/apostrophe passthrough, since a pronunciation string should
  // never contain those). Kept as a static field, not const, since
  // Dart doesn't allow const RegExp construction from a raw string
  // this way at the top level of a const-constructible class.
  static final _stripNonGreek = RegExp(r'[^\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036F]');

  /// Returns both pronunciation forms for [greekWord].
  /// Modern Greek romanization is a simple lowercase strip of the word
  /// (TTS handles the actual phonetics; this is just the display label).
  /// Koine is generated deterministically by KoinePhoneticService — this
  /// on-screen phonetic spelling is unaffected by the audio decision
  /// above.
  ///
  /// [greekWord] is stripped of anything that isn't a Greek letter
  /// before either pronunciation form is generated. Callers throughout
  /// the app pass raw verse tokens (which often carry trailing/leading
  /// punctuation straight from the source text, e.g. "λόγος," or
  /// "(καὶ") rather than pre-normalized words -- without this strip,
  /// both _modernRomanize and KoinePhoneticService.generateKoinePhonetic
  /// pass any unmapped character straight through into their output
  /// (their `map[ch] ?? ch` fallback), so a raw token would produce a
  /// pronunciation string with a stray comma or parenthesis stuck onto
  /// it. Stripping once here, at the single shared entry point, fixes
  /// this for every call site in the app without needing each caller
  /// to remember to pre-normalize its input.
  PronunciationPair getPair(String greekWord) {
    final cleaned = greekWord.replaceAll(_stripNonGreek, '');
    if (cleaned.isEmpty) {
      return const PronunciationPair(modernGreek: '', koineGreek: '');
    }

    final modern = _modernRomanize(cleaned);
    final koine = _koine.generateKoinePhonetic(cleaned);

    return PronunciationPair(
      modernGreek: modern,
      koineGreek: koine,
    );
  }

  /// Plays the Modern Greek pronunciation of [greekWord] or [greekText]
  /// via TTS. Feeds the Greek text directly — no transformation applied.
  Future<void> speak(String greekWord) async {
    await TtsService.instance.speak(greekWord);
  }

  /// Plays authentic Modern Greek audio for [greekText] — a single word
  /// or a whole verse. See class doc: this used to be a distinct
  /// Koine-sounding pathway; that was removed after real testing showed
  /// it wasn't reliable, so this is now equivalent to [speak].
  Future<void> speakKoine(String greekText) async {
    await speak(greekText);
  }

  /// Stops any current pronunciation audio.
  Future<void> stop() async {
    await TtsService.instance.stop();
  }

  /// Simple Modern Greek romanization for display alongside the TTS
  /// button. Maps each Greek letter to its modern pronunciation
  /// equivalent (e.g. η → i, υ → i, ω → o). This is NOT used for TTS
  /// input — TTS receives the raw Greek text directly.
  String _modernRomanize(String greekWord) {
    const Map<String, String> modern = {
      'α': 'a', 'β': 'v', 'γ': 'g', 'δ': 'th', 'ε': 'e',
      'ζ': 'z', 'η': 'i', 'θ': 'th', 'ι': 'i', 'κ': 'k',
      'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'ks', 'ο': 'o',
      'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'τ': 't',
      'υ': 'i', 'φ': 'f', 'χ': 'ch', 'ψ': 'ps', 'ω': 'o',
    };

    final buf = StringBuffer();
    final lower = greekWord.toLowerCase();
    for (final ch in lower.runes.map(String.fromCharCode)) {
      final base = _baseLetter(ch);
      buf.write(modern[base] ?? base);
    }
    return buf.toString();
  }

  // Minimal diacritic stripper — same table as KoinePhoneticService
  // but only the entries needed for the modern romanization path.
  String _baseLetter(String ch) {
    const Map<String, String> d = {
      'ἀ': 'α', 'ἁ': 'α', 'ἂ': 'α', 'ἃ': 'α', 'ἄ': 'α', 'ἅ': 'α',
      'ἆ': 'α', 'ἇ': 'α', 'ὰ': 'α', 'ά': 'α', 'ᾶ': 'α', 'ᾳ': 'α',
      'ἐ': 'ε', 'ἑ': 'ε', 'ἔ': 'ε', 'ἕ': 'ε', 'ὲ': 'ε', 'έ': 'ε',
      'ἠ': 'η', 'ἡ': 'η', 'ἤ': 'η', 'ἥ': 'η', 'ὴ': 'η', 'ή': 'η',
      'ῆ': 'η', 'ῃ': 'η',
      'ἰ': 'ι', 'ἱ': 'ι', 'ἴ': 'ι', 'ἵ': 'ι', 'ὶ': 'ι', 'ί': 'ι',
      'ῖ': 'ι',
      'ὀ': 'ο', 'ὁ': 'ο', 'ὄ': 'ο', 'ὅ': 'ο', 'ὸ': 'ο', 'ό': 'ο',
      'ὐ': 'υ', 'ὑ': 'υ', 'ὔ': 'υ', 'ὕ': 'υ', 'ὺ': 'υ', 'ύ': 'υ',
      'ῦ': 'υ',
      'ὠ': 'ω', 'ὡ': 'ω', 'ὤ': 'ω', 'ὥ': 'ω', 'ὼ': 'ω', 'ώ': 'ω',
      'ῶ': 'ω', 'ῳ': 'ω',
      'ῤ': 'ρ', 'ῥ': 'ρ',
    };
    return d[ch] ?? ch;
  }
}