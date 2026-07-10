// lib/data/services/sound_service.dart

import 'package:audioplayers/audioplayers.dart';

/// Plays short sound effects for quiz feedback.
///
/// Asset paths (drop your audio files here):
///   assets/sounds/correct.mp3   — played on correct answer
///   assets/sounds/incorrect.mp3 — played on incorrect answer
///
/// Files are not included in the repo — add your own mp3 or wav files
/// at the paths above and they will be picked up automatically.
/// Free sources: freesound.org, mixkit.co (filter: "correct", "wrong").
///
/// Usage:
///   await SoundService.instance.playCorrect();
///   await SoundService.instance.playIncorrect();
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  // Two separate players so correct and incorrect can overlap if needed
  // (e.g. user answers quickly). AudioPlayer is lightweight enough that
  // two instances add negligible overhead.
  final AudioPlayer _correctPlayer   = AudioPlayer();
  final AudioPlayer _incorrectPlayer = AudioPlayer();

  static const _correctPath   = 'sounds/correct.mp3';
  static const _incorrectPath = 'sounds/incorrect.mp3';

  /// Plays the correct-answer ding. No-ops silently if the asset is
  /// missing — sound effects are non-critical and should never crash
  /// the quiz flow.
  Future<void> playCorrect() async {
    try {
      await _correctPlayer.play(AssetSource(_correctPath));
    } catch (_) {
      // Asset not yet present — placeholder mode, ignore.
    }
  }

  /// Plays the incorrect-answer buzzer.
  Future<void> playIncorrect() async {
    try {
      await _incorrectPlayer.play(AssetSource(_incorrectPath));
    } catch (_) {
      // Asset not yet present — placeholder mode, ignore.
    }
  }

  /// Releases both players. Call on app termination if needed.
  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _incorrectPlayer.dispose();
  }
}