// lib/domain/usecases/backup_usecase.dart

import '../../data/services/hive_service.dart';

/// Builds and restores a full local backup of every Hive box this app
/// uses. "Manual" backup per the handoff doc's to-do list — no cloud
/// SDK, no auth: the resulting JSON is handed to the OS share sheet
/// (ExportService, already built for CSV export) so the user can save
/// it to iCloud Drive, Google Drive, or anywhere else their share sheet
/// offers. Restore reverses this from a previously exported file.
///
/// Pure — no file I/O, no platform channels — same reasoning as
/// ExportVocabularyUseCase and QuizEngine staying I/O-free.
class BackupUseCase {
  const BackupUseCase();

  static const _formatVersion = 1;

  /// Reads every relevant Hive box and returns a JSON-safe map. Every
  /// value already stored in these boxes is JSON-safe (each model's own
  /// toMap() ensured that — see verse_progress_model.dart,
  /// parsing_progress_model.dart, etc.), so no further conversion is
  /// needed here beyond assembling the box map itself.
  Future<Map<String, dynamic>> buildBackup(String pairKey) async {
    final boxNames = _allBoxNames(pairKey);
    final boxes = <String, dynamic>{};

    for (final name in boxNames) {
      final box = await HiveService.openBox(name);
      boxes[name] = {
        for (final key in box.keys) key.toString(): box.get(key),
      };
    }

    return {
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'pairKey': pairKey,
      'boxes': boxes,
    };
  }

  /// Restores every box present in [backup]. DESTRUCTIVE: clears each
  /// box before repopulating it from the backup contents, so anything
  /// recorded after the backup was taken is lost for that box. Callers
  /// MUST get explicit user confirmation before calling this — there is
  /// no undo once boxes are cleared. Unrecognized formatVersion is
  /// rejected rather than guessed at, since a silent partial restore
  /// would be worse than a clear failure.
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    final version = backup['formatVersion'];
    if (version != _formatVersion) {
      throw FormatException(
        'Unsupported backup format version: $version. '
        'This app supports version $_formatVersion.',
      );
    }

    final boxesRaw = backup['boxes'];
    if (boxesRaw is! Map) {
      throw const FormatException('Backup file is missing its "boxes" data.');
    }

    for (final entry in boxesRaw.entries) {
      final boxName = entry.key as String;
      final data = entry.value;
      if (data is! Map) continue; // skip anything malformed rather than throw
      final box = await HiveService.openBox(boxName);
      await box.clear();
      await box.putAll(Map<String, dynamic>.from(data));
    }
  }

  List<String> _allBoxNames(String pairKey) => [
        HiveService.settings,
        HiveService.userProfile,
        HiveService.readingProgress,
        'vocab_$pairKey',
        HiveService.verseProgressBoxName(pairKey),
        HiveService.parsingProgressBoxName(pairKey),
      ];
}