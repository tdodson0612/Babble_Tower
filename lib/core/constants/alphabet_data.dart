// lib/core/constants/alphabet_data.dart

/// Represents a single character/letter in the Greek alphabet.
class LetterEntry {
  /// The character as displayed in Greek.
  final String character;

  /// Uppercase variant (if applicable).
  final String? uppercase;

  /// Romanized pronunciation guide.
  final String romanized;

  /// Plain-English pronunciation description shown to the user.
  final String pronunciation;

  /// The letter's traditional name (e.g. "Alpha", "Beta"). Added for the
  /// alphabet quiz's "name" skill — distinct from [romanized] (the
  /// phonetic transliteration, e.g. "g" for gamma) and [pronunciation]
  /// (how it sounds). "What is this letter CALLED" is a different
  /// question from "what SOUND does it make," and needs its own field.
  final String name;

  /// An example word in Greek containing this letter.
  final String exampleWord;

  /// What that example word means in English.
  final String exampleMeaning;

  /// IPA symbol (optional, for advanced learners).
  final String? ipa;

  const LetterEntry({
    required this.character,
    this.uppercase,
    required this.romanized,
    required this.pronunciation,
    required this.name,
    required this.exampleWord,
    required this.exampleMeaning,
    this.ipa,
  });
}

/// Full alphabet definition for a language.
class AlphabetData {
  final String languageCode;
  final String languageName;

  /// Short note shown at top of alphabet screen.
  final String scriptNote;

  /// True if script runs right-to-left.
  final bool isRtl;

  final List<LetterEntry> letters;

  const AlphabetData({
    required this.languageCode,
    required this.languageName,
    required this.scriptNote,
    this.isRtl = false,
    required this.letters,
  });
}

// ---------------------------------------------------------------------------
// Greek alphabet — the only alphabet Babble Tower teaches.
// ---------------------------------------------------------------------------

const AlphabetData greekAlphabetData = AlphabetData(
  languageCode: 'el',
  languageName: 'Greek',
  scriptNote:
      'Greek uses its own 24-letter alphabet. Many letters look similar to English but sound different.',
  letters: [
    LetterEntry(character: 'α', uppercase: 'Α', romanized: 'a', pronunciation: 'Like "a" in "father"', name: 'Alpha', exampleWord: 'ἀγάπη', exampleMeaning: 'love', ipa: 'a'),
    LetterEntry(character: 'β', uppercase: 'Β', romanized: 'b/v', pronunciation: 'Like "v" in modern Greek; "b" in ancient', name: 'Beta', exampleWord: 'βίβλος', exampleMeaning: 'book', ipa: 'β'),
    LetterEntry(character: 'γ', uppercase: 'Γ', romanized: 'g', pronunciation: 'Like "g" in "go", or soft like "y" before e/i', name: 'Gamma', exampleWord: 'γῆ', exampleMeaning: 'earth', ipa: 'ɣ'),
    LetterEntry(character: 'δ', uppercase: 'Δ', romanized: 'd', pronunciation: 'Like "th" in "this" (modern); "d" in ancient', name: 'Delta', exampleWord: 'δόξα', exampleMeaning: 'glory', ipa: 'ð'),
    LetterEntry(character: 'ε', uppercase: 'Ε', romanized: 'e', pronunciation: 'Short "e" like in "pet"', name: 'Epsilon', exampleWord: 'ἐν', exampleMeaning: 'in', ipa: 'e'),
    LetterEntry(character: 'ζ', uppercase: 'Ζ', romanized: 'z', pronunciation: 'Like "z" in "zebra"', name: 'Zeta', exampleWord: 'ζωή', exampleMeaning: 'life', ipa: 'z'),
    LetterEntry(character: 'η', uppercase: 'Η', romanized: 'ē', pronunciation: 'Long "e" like in "feet"', name: 'Eta', exampleWord: 'ἡμέρα', exampleMeaning: 'day', ipa: 'i'),
    LetterEntry(character: 'θ', uppercase: 'Θ', romanized: 'th', pronunciation: 'Like "th" in "think"', name: 'Theta', exampleWord: 'θεός', exampleMeaning: 'God', ipa: 'θ'),
    LetterEntry(character: 'ι', uppercase: 'Ι', romanized: 'i', pronunciation: 'Like "ee" in "feet"', name: 'Iota', exampleWord: 'ἰδού', exampleMeaning: 'behold', ipa: 'i'),
    LetterEntry(character: 'κ', uppercase: 'Κ', romanized: 'k', pronunciation: 'Like "k" in "key"', name: 'Kappa', exampleWord: 'κύριος', exampleMeaning: 'Lord', ipa: 'k'),
    LetterEntry(character: 'λ', uppercase: 'Λ', romanized: 'l', pronunciation: 'Like "l" in "light"', name: 'Lambda', exampleWord: 'λόγος', exampleMeaning: 'word', ipa: 'l'),
    LetterEntry(character: 'μ', uppercase: 'Μ', romanized: 'm', pronunciation: 'Like "m" in "mother"', name: 'Mu', exampleWord: 'μήτηρ', exampleMeaning: 'mother', ipa: 'm'),
    LetterEntry(character: 'ν', uppercase: 'Ν', romanized: 'n', pronunciation: 'Like "n" in "night"', name: 'Nu', exampleWord: 'νόμος', exampleMeaning: 'law', ipa: 'n'),
    LetterEntry(character: 'ξ', uppercase: 'Ξ', romanized: 'x', pronunciation: 'Like "x" in "fox"', name: 'Xi', exampleWord: 'ξένος', exampleMeaning: 'stranger', ipa: 'ks'),
    LetterEntry(character: 'ο', uppercase: 'Ο', romanized: 'o', pronunciation: 'Short "o" like in "pot"', name: 'Omicron', exampleWord: 'ὁδός', exampleMeaning: 'way/road', ipa: 'o'),
    LetterEntry(character: 'π', uppercase: 'Π', romanized: 'p', pronunciation: 'Like "p" in "peace"', name: 'Pi', exampleWord: 'πατήρ', exampleMeaning: 'father', ipa: 'p'),
    LetterEntry(character: 'ρ', uppercase: 'Ρ', romanized: 'r', pronunciation: 'Rolled "r"', name: 'Rho', exampleWord: 'ῥῆμα', exampleMeaning: 'word/saying', ipa: 'r'),
    LetterEntry(character: 'σ/ς', uppercase: 'Σ', romanized: 's', pronunciation: 'Like "s" in "sun" (ς used at end of word)', name: 'Sigma', exampleWord: 'σάρξ', exampleMeaning: 'flesh', ipa: 's'),
    LetterEntry(character: 'τ', uppercase: 'Τ', romanized: 't', pronunciation: 'Like "t" in "time"', name: 'Tau', exampleWord: 'τέκνον', exampleMeaning: 'child', ipa: 't'),
    LetterEntry(character: 'υ', uppercase: 'Υ', romanized: 'y/u', pronunciation: 'Like "ee" in modern Greek; "u" in ancient', name: 'Upsilon', exampleWord: 'υἱός', exampleMeaning: 'son', ipa: 'i'),
    LetterEntry(character: 'φ', uppercase: 'Φ', romanized: 'ph/f', pronunciation: 'Like "f" in "faith"', name: 'Phi', exampleWord: 'φῶς', exampleMeaning: 'light', ipa: 'f'),
    LetterEntry(character: 'χ', uppercase: 'Χ', romanized: 'ch', pronunciation: 'Like "ch" in Scottish "loch"', name: 'Chi', exampleWord: 'χάρις', exampleMeaning: 'grace', ipa: 'x'),
    LetterEntry(character: 'ψ', uppercase: 'Ψ', romanized: 'ps', pronunciation: 'Like "ps" in "lips"', name: 'Psi', exampleWord: 'ψυχή', exampleMeaning: 'soul', ipa: 'ps'),
    LetterEntry(character: 'ω', uppercase: 'Ω', romanized: 'ō', pronunciation: 'Long "o" like in "tone"', name: 'Omega', exampleWord: 'ὥρα', exampleMeaning: 'hour', ipa: 'o'),
  ],
);