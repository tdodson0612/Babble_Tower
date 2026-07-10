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

  /// Returns both pronunciation forms for [greekWord].
  /// Modern Greek romanization is a simple lowercase strip of the word
  /// (TTS handles the actual phonetics; this is just the display label).
  /// Koine is generated deterministically by KoinePhoneticService — this
  /// on-screen phonetic spelling is unaffected by the audio decision
  /// above.
  PronunciationPair getPair(String greekWord) {
    if (greekWord.isEmpty) {
      return const PronunciationPair(modernGreek: '', koineGreek: '');
    }

    final modern = _modernRomanize(greekWord);
    final koine = _koine.generateKoinePhonetic(greekWord);

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