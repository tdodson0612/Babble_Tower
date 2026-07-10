#!/usr/bin/env python3
"""
diagnose_lemma_mismatch.py

Run from the project root:

    python3 diagnose_lemma_mismatch.py

Cross-references every lemma actually produced by build_morphology.py
(assets/morphology/*.json) against the keys in
assets/word_families/lexicon.json (build_word_families.py's output), to
check whether WordFamilyService.lookup()'s exact string match is quietly
missing entries it should find — specifically checking the hypothesis
that MorphGNT lowercases all lemmas uniformly (including proper nouns)
while Strong's dictionary keeps traditional capitalization on proper
nouns, which would make every person/place name in the Gospels fail to
resolve family data while common nouns/verbs work fine.

Does NOT modify any files. Read-only diagnostic.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MORPHOLOGY_DIR = ROOT / "assets" / "morphology"
LEXICON_PATH = ROOT / "assets" / "word_families" / "lexicon.json"

# A handful of well-known proper nouns to call out by name in the report,
# regardless of what the aggregate stats show — these are the ones a
# user would notice missing immediately while reading the Gospels.
KNOWN_PROPER_NOUNS_LOWER = {
    "ἰησοῦς", "πέτρος", "ἰωάννης", "παῦλος", "ἰάκωβος", "ἀνδρέας",
    "φίλιππος", "θωμᾶς", "ματθαῖος", "μαρία", "ἰερουσαλήμ",
    "γαλιλαία", "ναζαρέτ", "καπερναούμ", "ἰουδαία",
}


def load_morphology_lemmas() -> set:
    """Every distinct lemma string that appears anywhere in
    assets/morphology/*.json, exactly as build_morphology.py wrote it
    (no normalization applied here — we want the raw, real values)."""
    lemmas = set()
    if not MORPHOLOGY_DIR.exists():
        print(f"WARNING: {MORPHOLOGY_DIR} does not exist.")
        return lemmas

    files = sorted(MORPHOLOGY_DIR.glob("*.json"))
    if not files:
        print(f"WARNING: no .json files found in {MORPHOLOGY_DIR}.")
        return lemmas

    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        for chapter_words in data.get("chapters", {}).values():
            for verse_words in chapter_words.values():
                for w in verse_words:
                    lemma = w.get("lemma", "")
                    if lemma:
                        lemmas.add(lemma)
    return lemmas


def load_lexicon_keys() -> set:
    if not LEXICON_PATH.exists():
        print(f"WARNING: {LEXICON_PATH} does not exist.")
        return set()
    data = json.loads(LEXICON_PATH.read_text(encoding="utf-8"))
    return set(data.keys())


def main():
    morphology_lemmas = load_morphology_lemmas()
    lexicon_keys = load_lexicon_keys()

    if not morphology_lemmas or not lexicon_keys:
        print("Cannot run comparison — one or both source sets are empty.")
        return

    lexicon_keys_lower = {k.lower(): k for k in lexicon_keys}

    exact_matches = []
    case_insensitive_only = []
    no_match_at_all = []

    for lemma in sorted(morphology_lemmas):
        if lemma in lexicon_keys:
            exact_matches.append(lemma)
        elif lemma.lower() in lexicon_keys_lower:
            case_insensitive_only.append(
                (lemma, lexicon_keys_lower[lemma.lower()])
            )
        else:
            no_match_at_all.append(lemma)

    total = len(morphology_lemmas)
    print("=" * 70)
    print("LEMMA MATCHING DIAGNOSTIC")
    print("=" * 70)
    print(f"Distinct lemmas produced by build_morphology.py: {total}")
    print(f"Distinct keys in word_families lexicon.json:     {len(lexicon_keys)}")
    print()
    print(f"Exact matches (WordFamilyService.lookup succeeds): "
          f"{len(exact_matches)} ({len(exact_matches)/total*100:.1f}%)")
    print(f"Case-insensitive-only matches (would succeed if lookup "
          f"lowercased both sides): {len(case_insensitive_only)} "
          f"({len(case_insensitive_only)/total*100:.1f}%)")
    print(f"No match at all, even case-insensitively: "
          f"{len(no_match_at_all)} ({len(no_match_at_all)/total*100:.1f}%)")
    print()

    if case_insensitive_only:
        print("-" * 70)
        print(f"CASE-INSENSITIVE-ONLY MISMATCHES (first 30 of "
              f"{len(case_insensitive_only)}):")
        print("  morphology lemma  ->  lexicon key")
        for lemma, lex_key in case_insensitive_only[:30]:
            flag = " <-- known proper noun" if lemma.lower() in KNOWN_PROPER_NOUNS_LOWER else ""
            print(f"  {lemma!r:20s} -> {lex_key!r}{flag}")
        print()

    print("-" * 70)
    print("KNOWN PROPER NOUN CHECK (specific words to watch for):")
    for name in sorted(KNOWN_PROPER_NOUNS_LOWER):
        # Find any morphology lemma that matches case-insensitively,
        # since we don't know its exact stored case up front.
        candidates = [l for l in morphology_lemmas if l.lower() == name]
        if not candidates:
            print(f"  {name:15s} -- not found in morphology data at all "
                  f"(may just not appear/align in these 4 books)")
            continue
        for candidate in candidates:
            status = (
                "EXACT MATCH (OK)" if candidate in lexicon_keys
                else "CASE MISMATCH (BUG)" if candidate.lower() in lexicon_keys_lower
                else "NO MATCH AT ALL"
            )
            print(f"  {candidate!r:20s} -> {status}")
    print("=" * 70)


if __name__ == "__main__":
    main()