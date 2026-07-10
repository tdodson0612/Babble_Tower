// lib/data/services/backup_file_service.dart

import 'dart:convert';
import 'package:file_picker/file_picker.dart';

/// Opens the native file picker restricted to JSON files, for restoring
/// a previously exported backup (see backup_usecase.dart / export_service.dart
/// for the export side — this is the read-back half). Uses
/// FilePicker.platform.pickFiles — confirmed against the actual resolved
/// package version (pub.dev's front-page examples show a static
/// FilePicker.pickFiles() for a newer/prerelease API line than what
/// resolved here; the instance-based .platform accessor is what
/// actually compiles against this project's pinned version).
class BackupFileService {
  const BackupFileService();

  /// Returns the parsed JSON content of the file the user picked, or
  /// null if they cancelled the picker. Throws FormatException if the
  /// selected file isn't valid JSON — callers should surface that as an
  /// error message, not a silent failure, since picking the wrong file
  /// is a plausible and recoverable user mistake.
  Future<Map<String, dynamic>?> pickAndReadJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.first.bytes;
    if (bytes == null) return null;

    final content = utf8.decode(bytes);
    return json.decode(content) as Map<String, dynamic>;
  }
}