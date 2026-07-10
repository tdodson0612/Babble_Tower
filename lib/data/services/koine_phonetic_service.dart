// lib/data/services/koine_phonetic_service.dart

/// Generates a display-only Koine phonetic approximation for a Greek word.
///
/// Rules (from project handoff doc):
///   - Break syllables logically
///   - Avoid modern Greek vowel-merger shifts where possible
///   - Keep output readable and consistent
///   - Prioritize stability over perfect linguistics
///   - This is a DISPLAY SYSTEM, not linguistic accuracy perfection
///
/// Implementation note: a fully accurate Erasmian reconstruction would
/// require morphological tagging and accent-sensitive rules. This is a
/// lightweight deterministic approximation suitable for learner display.
/// Accuracy is good for common words; complex diphthongs and rare letter
/// combinations may produce simplified output. This is the accepted
/// tradeoff noted in the project handoff doc.
class KoinePhoneticService {
  const KoinePhoneticService();

  /// Returns a syllabified phonetic string for [greekWord].
  /// Strips diacritics first, maps each character/digraph to its Koine
  /// phonetic equivalent, then inserts syllable breaks.
  String generateKoinePhonetic(String greekWord) {
    if (greekWord.isEmpty) return '';

    // Step 1: strip diacritics (accents, breathings, iota subscript)
    // keeping only the base Greek letter.
    final stripped = _stripDiacritics(greekWord.toLowerCase());

    // Step 2: map digraphs and single letters to phonetic strings.
    final phonetic = _mapToPhonetic(stripped);

    // Step 3: insert syllable breaks using simple vowel-boundary rules.
    return _syllabify(phonetic);
  }

  // ── Step 1: strip diacritics ─────────────────────────────────────────

  String _stripDiacritics(String word) {
    // Unicode ranges:
    // - Extended Greek with diacritics: U+1F00–U+1FFF
    // - Combining marks: U+0300–U+036F
    // Map common precomposed forms to their bare base letter.
    final result = StringBuffer();
    for (final ch in word.runes.map(String.fromCharCode)) {
      result.write(_baseLetter(ch));
    }
    return result.toString();
  }

  String _baseLetter(String ch) {
    const Map<String, String> diacriticMap = {
      // Alpha variants (U+1F00–U+1F0F, U+1F70–U+1F71, U+1FB0–U+1FB4, U+1FB6–U+1FBC)
      'ἀ': 'α', 'ἁ': 'α', 'ἂ': 'α', 'ἃ': 'α', 'ἄ': 'α', 'ἅ': 'α',
      'ἆ': 'α', 'ἇ': 'α', 'ὰ': 'α', 'ά': 'α', 'ᾀ': 'α', 'ᾁ': 'α',
      'ᾂ': 'α', 'ᾃ': 'α', 'ᾄ': 'α', 'ᾅ': 'α', 'ᾆ': 'α', 'ᾇ': 'α',
      'ᾰ': 'α', 'ᾱ': 'α', 'ᾲ': 'α', 'ᾴ': 'α', 'ᾶ': 'α', 'ᾷ': 'α',
      'ᾳ': 'α',
      // Epsilon variants (U+1F10–U+1F15, U+1F72–U+1F73)
      'ἐ': 'ε', 'ἑ': 'ε', 'ἒ': 'ε', 'ἓ': 'ε', 'ἔ': 'ε', 'ἕ': 'ε',
      'ὲ': 'ε', 'έ': 'ε',
      // Eta variants (U+1F20–U+1F2F, U+1F74–U+1F75, U+1FC0–U+1FC4, U+1FC6–U+1FCC)
      'ἠ': 'η', 'ἡ': 'η', 'ἢ': 'η', 'ἣ': 'η', 'ἤ': 'η', 'ἥ': 'η',
      'ἦ': 'η', 'ἧ': 'η', 'ὴ': 'η', 'ή': 'η', 'ᾐ': 'η', 'ᾑ': 'η',
      'ᾒ': 'η', 'ᾓ': 'η', 'ᾔ': 'η', 'ᾕ': 'η', 'ᾖ': 'η', 'ᾗ': 'η',
      'ῂ': 'η', 'ῄ': 'η', 'ῆ': 'η', 'ῇ': 'η', 'ῃ': 'η',
      // Iota variants (U+1F30–U+1F3F, U+1F76–U+1F77, U+1FD0–U+1FD3, U+1FD6–U+1FD7)
      'ἰ': 'ι', 'ἱ': 'ι', 'ἲ': 'ι', 'ἳ': 'ι', 'ἴ': 'ι', 'ἵ': 'ι',
      'ἶ': 'ι', 'ἷ': 'ι', 'ὶ': 'ι', 'ί': 'ι', 'ῐ': 'ι', 'ῑ': 'ι',
      'ΐ': 'ι', 'ῖ': 'ι', 'ῗ': 'ι',
      // Omicron variants (U+1F40–U+1F45, U+1F78–U+1F79)
      'ὀ': 'ο', 'ὁ': 'ο', 'ὂ': 'ο', 'ὃ': 'ο', 'ὄ': 'ο', 'ὅ': 'ο',
      'ὸ': 'ο', 'ό': 'ο',
      // Upsilon variants (U+1F50–U+1F57, U+1F7A–U+1F7B, U+1FE0–U+1FE3, U+1FE6–U+1FE7)
      'ὐ': 'υ', 'ὑ': 'υ', 'ὒ': 'υ', 'ὓ': 'υ', 'ὔ': 'υ', 'ὕ': 'υ',
      'ὖ': 'υ', 'ὗ': 'υ', 'ὺ': 'υ', 'ύ': 'υ', 'ῠ': 'υ', 'ῡ': 'υ',
      'ΰ': 'υ', 'ῦ': 'υ', 'ῧ': 'υ',
      // Omega variants (U+1F60–U+1F6F, U+1F7C–U+1F7D, U+1FF0–U+1FF4, U+1FF6–U+1FFC)
      'ὠ': 'ω', 'ὡ': 'ω', 'ὢ': 'ω', 'ὣ': 'ω', 'ὤ': 'ω', 'ὥ': 'ω',
      'ὦ': 'ω', 'ὧ': 'ω', 'ὼ': 'ω', 'ώ': 'ω', 'ᾠ': 'ω', 'ᾡ': 'ω',
      'ᾢ': 'ω', 'ᾣ': 'ω', 'ᾤ': 'ω', 'ᾥ': 'ω', 'ᾦ': 'ω', 'ᾧ': 'ω',
      'ῲ': 'ω', 'ῴ': 'ω', 'ῶ': 'ω', 'ῷ': 'ω', 'ῳ': 'ω',
      // Rho variants
      'ῤ': 'ρ', 'ῥ': 'ρ',
    };
    return diacriticMap[ch] ?? ch;
  }

  // ── Step 2: map to phonetic ───────────────────────────────────────────

  /// Maps Greek letters/digraphs to Erasmian-style phonetic strings.
  /// Digraphs are checked before single letters so e.g. "αι" → "ai"
  /// before "α" → "a".
  String _mapToPhonetic(String stripped) {
    // Greek letter → Koine phonetic (Erasmian approximation)
    const Map<String, String> digraphs = {
      'αι': 'ai',
      'ει': 'ei',
      'οι': 'oi',
      'υι': 'ui',
      'αυ': 'au',
      'ευ': 'eu',
      'ου': 'ou',
      'γγ': 'ng',
      'γκ': 'nk',
      'γξ': 'nx',
      'γχ': 'nch',
    };

    const Map<String, String> letters = {
      'α': 'a',
      'β': 'b',
      'γ': 'g',
      'δ': 'd',
      'ε': 'e',
      'ζ': 'z',
      'η': 'ē', // long e — distinct from short epsilon in Koine
      'θ': 'th',
      'ι': 'i',
      'κ': 'k',
      'λ': 'l',
      'μ': 'm',
      'ν': 'n',
      'ξ': 'x',
      'ο': 'o',
      'π': 'p',
      'ρ': 'r',
      'σ': 's',
      'ς': 's',
      'τ': 't',
      'υ': 'y', // Koine upsilon — distinct from Modern Greek /i/
      'φ': 'ph',
      'χ': 'ch',
      'ψ': 'ps',
      'ω': 'ō', // long o — distinct from short omicron in Koine
    };

    final result = StringBuffer();
    var i = 0;
    while (i < stripped.length) {
      // Try digraph first
      if (i + 1 < stripped.length) {
        final pair = stripped.substring(i, i + 2);
        if (digraphs.containsKey(pair)) {
          result.write(digraphs[pair]);
          i += 2;
          continue;
        }
      }
      // Single letter
      final ch = stripped[i];
      result.write(letters[ch] ?? ch);
      i++;
    }
    return result.toString();
  }

  // ── Step 3: syllabify ─────────────────────────────────────────────────

  /// Inserts hyphens between syllables using a simple rule:
  /// split after every vowel sequence that is followed by a consonant
  /// and then another vowel (CV boundary). Good enough for learner
  /// display; not a full syllabification algorithm.
  String _syllabify(String phonetic) {
    if (phonetic.length <= 2) return phonetic;

    const vowels = {'a', 'e', 'i', 'o', 'u', 'ē', 'ō', 'y'};

    final result = StringBuffer();
    // Work on individual ASCII chars; multi-char phonemes (th, ph, etc.)
    // are already merged into single tokens by _mapToPhonetic, but the
    // output is a plain string so we iterate codeUnits.
    final chars = phonetic.split('');
    for (var i = 0; i < chars.length; i++) {
      result.write(chars[i]);
      // Insert hyphen between vowel-ending syllable and following
      // consonant that precedes another vowel: V | CV pattern.
      if (i + 2 < chars.length &&
          vowels.contains(chars[i]) &&
          !vowels.contains(chars[i + 1]) &&
          vowels.contains(chars[i + 2])) {
        result.write('-');
      }
    }
    return result.toString();
  }
}