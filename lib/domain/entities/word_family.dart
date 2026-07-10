// lib/domain/entities/word_family.dart

/// A word's root/cognate relationships, as resolved from
/// assets/word_families/lexicon.json (built by build_word_families.py
/// from Strong's dictionary's structured derivation data — see that
/// script's header comment for the full provenance).
///
/// [derivesFrom] and [derivedForms] are lemma strings, not nested
/// WordFamily objects — looking up a related word's own gloss or further
/// relations means calling WordFamilyService.lookup() again on that
/// lemma. This keeps the entity flat and avoids the lexicon needing to
/// duplicate every gloss at every relation site; the service already
/// holds the whole table in memory after first load, so a follow-up
/// lookup is free.
class WordFamily {
  final String lemma;
  final String strongsNumber;
  final String gloss;

  /// Root word(s) this lemma is built from, e.g. ἀγάπη -> [ἀγαπάω].
  /// Usually zero or one entry; occasionally two for compound words.
  final List<String> derivesFrom;

  /// Other lemmas that derive FROM this one — the inverse relationship,
  /// e.g. ἀγαπάω -> [ἀγάπη, ἀγαπητός, ...]. Can be a longer list for
  /// productive roots (λόγος has 19).
  final List<String> derivedForms;

  const WordFamily({
    required this.lemma,
    required this.strongsNumber,
    required this.gloss,
    required this.derivesFrom,
    required this.derivedForms,
  });

  bool get hasRelations => derivesFrom.isNotEmpty || derivedForms.isNotEmpty;

  factory WordFamily.fromJson(String lemma, Map<String, dynamic> json) {
    return WordFamily(
      lemma: lemma,
      strongsNumber: json['strongs'] as String,
      gloss: json['gloss'] as String,
      derivesFrom: (json['derivesFrom'] as List).cast<String>(),
      derivedForms: (json['derivedForms'] as List).cast<String>(),
    );
  }
}