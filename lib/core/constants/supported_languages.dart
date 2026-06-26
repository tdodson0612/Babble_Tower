// lib/core/constants/supported_languages.dart

/// Babble Tower now teaches a single fixed pair: English speakers
/// learning to read and write Koine Greek (the original language of
/// the Gospels). There is no language selection — these are constants,
/// not a list to choose from.
class AppLanguage {
  static const String nativeCode = 'en';
  static const String nativeName = 'English';

  static const String targetCode = 'el';
  static const String targetName = 'Greek';
  static const String targetNativeName = 'Ελληνικά';

  /// Composite key used for vocabulary storage (Hive box namespace).
  static const String pairKey = 'en_el';

  /// Dictionary key for translating words encountered WHILE READING —
  /// the Bible text is in Greek, so lookups go Greek -> English.
  /// This is intentionally the reverse of [pairKey], which only
  /// identifies the storage namespace, not lookup direction.
  static const String readingDictionaryKey = 'el_en';
}