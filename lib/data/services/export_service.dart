// lib/data/services/export_service.dart

import 'dart:io';
import 'package:flutter/material.dart' show Rect;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes exported content to a temp file and hands it to the OS share
/// sheet. Uses the app's temporary directory (path_provider) rather than
/// documents — an exported file is a one-shot handoff to Mail/Files/etc,
/// not app-owned data that needs to persist or be Hive-tracked.
class ExportService {
  const ExportService();

  /// UTF-8 byte-order-mark. Prepended to exported text content so
  /// Excel (especially on Windows) reliably detects the file as UTF-8
  /// instead of guessing a local 8-bit codepage and rendering Greek
  /// text as mojibake — a well-known, common pitfall for CSV files
  /// containing non-ASCII text with no BOM. Has no visible effect in
  /// any modern CSV reader that already handles UTF-8 correctly.
  static const _utf8Bom = '\uFEFF';

  /// Writes [content] to a temp file named [fileName] and opens the
  /// native share sheet (Mail, Files, AirDrop, Drive, etc. — whatever
  /// the OS offers) so the user can get it off the device. Throws on
  /// failure (disk full, plugin not available on this platform, etc.) —
  /// callers should wrap in try/catch and surface a message, same as
  /// every other fallible operation in this app.
  ///
  /// [sharePositionOrigin] is the on-screen rectangle of the button
  /// that triggered the export (see share_plus's docs). This is
  /// REQUIRED on iPad (the share sheet is a popover that needs an
  /// anchor point) and, as of iOS 26, share_plus throws a
  /// PlatformException on iPhone too if this is omitted or zero —
  /// confirmed against share_plus's own issue tracker, not a
  /// theoretical concern. Passed as a plain Rect (not a BuildContext)
  /// to keep this data-layer service decoupled from the widget tree;
  /// callers compute it from their own button's context.
  Future<void> exportAndShare({
    required String content,
    required String fileName,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString('$_utf8Bom$content');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}