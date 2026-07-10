// lib/data/services/tts_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Wrapper around flutter_tts, now serving TWO distinct pronunciation
/// needs with two distinct voices:
///
///   - [speak] — raw Greek text via a Modern Greek voice (el-GR). Used
///     for the "Modern Greek (TTS)" row in the pronunciation panel and
///     the quiz screen's speaker button.
///   - [speakPhonetic] — an English-alphabet Koine phonetic respelling
///     (see KoinePhoneticService.generateKoinePhoneticForTts) via an
///     English voice. Used for Listening Recognition questions.
///
/// Why two paths instead of one: no mainstream TTS engine has a genuine
/// Koine Greek voice (a dead/reconstructed pronunciation has no
/// commercial demand), and feeding raw Greek script to either a Modern
/// Greek voice OR an English voice produces wrong results for Koine
/// specifically — a Modern Greek voice applies modern sound-shift rules
/// (e.g. η/ι/υ all merging toward "ee"), while an English voice just
/// misreads the unfamiliar script outright. Feeding an ENGLISH voice an
/// ENGLISH-ALPHABET phonetic spelling plays to what it's actually good
/// at: reading unfamiliar Latin-alphabet text phonetically. It's a
/// deliberate approximation, not genuine Koine audio — see the project
/// conversation history for the fuller reasoning (espeak-ng's `grc`
/// voice was evaluated and rejected as too robotic-sounding).
///
/// KNOWN LIMITATION on [speak] specifically (not a code bug): flutter_tts
/// pulls voices from the underlying platform (on web/macOS, that's
/// Chrome's Web Speech API, backed by whatever TTS voices are installed
/// at the OS level). If no genuine Greek voice is installed,
/// setLanguage('el-GR') silently falls back to a default voice reading
/// Greek letters using that voice's own pronunciation rules.
///
/// Fix for [speak]'s limitation: install a real Greek system voice.
///   macOS: System Settings → Accessibility → Spoken Content → System
///     Voice → Manage Voices → find a Greek voice (e.g. "Melina").
///   Android: Settings → Language & input → Text-to-speech output →
///     Install voice data → Greek.
///   iOS: ships Greek voices by default in many regions already.
///
/// Usage:
///   await TtsService.instance.speak('λόγος');           // Modern Greek
///   await TtsService.instance.speakPhonetic('lo-gos');  // Koine approx.
///   await TtsService.instance.stop();
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setSpeechRate(0.5); // slower for learner clarity
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);

    // Debug-only diagnostic — logs whether a real Greek voice exists on
    // this device/browser, so a Modern Greek pronunciation complaint can
    // be told apart from a genuine code bug at a glance in the run
    // terminal. Deliberately NOT awaited: on the very first-ever speak()
    // call, awaiting this here would delay the actual _tts.speak() call
    // past Chrome's user-gesture window (speechSynthesis.speak() needs
    // to fire close to the triggering tap or Chrome can reject it
    // outright with a raw SpeechSynthesisErrorEvent — a real bug this
    // diagnostic accidentally caused once, by adding an extra await
    // right before the first speak() call of a session).
    if (kDebugMode) {
      hasGreekVoice().then((hasVoice) {
        debugPrint(
          hasVoice
              ? '[TtsService] Greek voice found — Modern Greek pronunciation should be accurate.'
              : '[TtsService] NO Greek voice found on this device/browser. '
                  'speak() will fall back to a default voice reading Greek '
                  'letters with that voice\'s own pronunciation rules. See '
                  'tts_service.dart\'s class doc for how to install a real '
                  'Greek voice, or use speakPhonetic() for Koine words instead.',
        );
      });
    }
  }

  /// Checks the platform's actual voice list for anything tagged as
  /// Greek (locale starting with "el"). Returns false if the platform
  /// doesn't expose getVoices() (some platforms don't) rather than
  /// throwing — treat that as "couldn't confirm," not "definitely no
  /// Greek voice."
  Future<bool> hasGreekVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return false;
      return voices.any((v) {
        if (v is! Map) return false;
        final locale = (v['locale'] ?? v['name'] ?? '').toString().toLowerCase();
        return locale.startsWith('el');
      });
    } catch (_) {
      return false;
    }
  }

  /// Speaks [text] (raw Greek) using a Modern Greek voice. Language is
  /// set explicitly on every call — not just once during init — so this
  /// can never end up stuck on whatever [speakPhonetic] last set.
  Future<void> speak(String text) async {
    await _init();
    if (_speaking) await _tts.stop();
    await _tts.setLanguage('el-GR');
    await _tts.speak(text);
  }

  /// Speaks [phoneticText] — an English-alphabet Koine phonetic
  /// respelling — using an English voice. See class doc for why. Sets
  /// language explicitly on every call for the same reason as [speak].
  Future<void> speakPhonetic(String phoneticText) async {
    await _init();
    if (_speaking) await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.speak(phoneticText);
  }

  /// Stops any current speech.
  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
  }
}