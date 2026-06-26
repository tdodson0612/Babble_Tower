// lib/core/constants/book_names.dart

/// Gospel book names, indexed by language code.
/// Order: Matthew, Mark, Luke, John.
///
/// Babble Tower now reads a single fixed pair (English speakers
/// reading Koine Greek), so only these two entries remain. HomeScreen
/// uses 'el' as the primary label on book chips and 'en' as the
/// English subtitle underneath.
const Map<String, List<String>> kBookNames = {
  'en': [
    'Matthew', 'Mark', 'Luke', 'John',
  ],
  'el': [
    'Ματθαῖος', 'Μάρκος', 'Λουκᾶς', 'Ἰωάννης',
  ],
};

/// Returns the list of Gospel book names for [languageCode],
/// falling back to English if not found.
List<String> getBookNames(String languageCode) =>
    kBookNames[languageCode] ?? kBookNames['en']!;