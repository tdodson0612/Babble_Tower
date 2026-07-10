#!/usr/bin/env python3
"""
diagnose_lemma_mismatch_v2.py

Run from the project root, same as diagnose_lemma_mismatch.py:

    python3 diagnose_lemma_mismatch_v2.py

Follow-up to the first diagnostic. That one ruled out "MorphGNT
lowercases proper nouns" as the main cause (only 1 real case mismatch
found: βαπτιστής/Βαπτιστής). But 475 lemmas (18.6%) had NO match at
all, even case-insensitively — including Ἰησοῦς ("Jesus"), which is
about as suspicious a miss as this app could have.

This script tests a different hypothesis: Unicode normalization form.
The same visible character can be encoded as one "precomposed" codepoint
(e.g. U+1FE6 for upsilon-with-circumflex) or as a "decomposed" sequence
(plain upsilon U+03C5 + a separate combining-circumflex U+0342 codepoint)
— visually identical, byte-for-byte different, so an exact string match
silently fails. This is a DIFFERENT bug from the oxia/tonos codepoint
substitution already found and fixed in build_word_families.py — that
fix only touches 7 specific acute-accented vowels, not general
normalization form.

Does NOT modify any files. Read-only diagnostic.
"""

import json
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MORPHOLOGY_DIR = ROOT / "assets" / "morphology"
LEXICON_PATH = ROOT / "assets" / "word_families" / "lexicon.json"


def load_morphology_lemmas() -> set:
    lemmas = set()
    for path in sorted(MORPHOLOGY_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for chapter_words in data.get("chapters", {}).values():
            for verse_words in chapter_words.values():
                for w in verse_words:
                    lemma = w.get("lemma", "")
                    if lemma:
                        lemmas.add(lemma)
    return lemmas


def load_lexicon_keys() -> set:
    data = json.loads(LEXICON_PATH.read_text(encoding="utf-8"))
    return set(data.keys())


def codepoint_dump(s: str) -> str:
    """Shows each character's codepoint and Unicode name, so two
    visually-identical strings can be compared byte-for-byte."""
    lines = []
    for ch in s:
        try:
            name = unicodedata.name(ch)
        except ValueError:
            name = "<no name>"
        lines.append(f"    U+{ord(ch):04X}  {ch!r:6s}  {name}")
    return "\n".join(lines)


def main():
    morphology_lemmas = load_morphology_lemmas()
    lexicon_keys = load_lexicon_keys()

    # ── Step 1: does NFC normalization fix it? ──────────────────────────
    morphology_nfc = {unicodedata.normalize("NFC", l): l for l in morphology_lemmas}
    lexicon_nfc = {unicodedata.normalize("NFC", k): k for k in lexicon_keys}

    no_match_raw = [l for l in morphology_lemmas if l not in lexicon_keys]
    fixed_by_nfc = [
        l for l in no_match_raw
        if unicodedata.normalize("NFC", l) in lexicon_nfc
    ]
    still_broken_after_nfc = [
        l for l in no_match_raw
        if unicodedata.normalize("NFC", l) not in lexicon_nfc
    ]

    print("=" * 70)
    print("NFC NORMALIZATION TEST")
    print("=" * 70)
    print(f"Lemmas with no exact match: {len(no_match_raw)}")
    print(f"  -> fixed by NFC normalization on both sides: {len(fixed_by_nfc)}")
    print(f"  -> still no match after NFC normalization:   {len(still_broken_after_nfc)}")
    print()

    if fixed_by_nfc:
        print(f"Examples fixed by NFC (first 15 of {len(fixed_by_nfc)}):")
        for l in fixed_by_nfc[:15]:
            matched_key = lexicon_nfc[unicodedata.normalize("NFC", l)]
            print(f"  {l!r} -> {matched_key!r}")
        print()

    if still_broken_after_nfc:
        print(f"Still broken even after NFC (first 15 of "
              f"{len(still_broken_after_nfc)}) -- these are NOT an "
              f"encoding issue, something else is going on:")
        for l in still_broken_after_nfc[:15]:
            print(f"  {l!r}")
        print()

    # ── Step 2: byte-for-byte dump of the Jesus case specifically ───────
    print("=" * 70)
    print("BYTE-FOR-BYTE DUMP: 'Ἰησοῦς' (Jesus)")
    print("=" * 70)

    morphology_jesus = [l for l in morphology_lemmas if "ησο" in l.lower()]
    lexicon_jesus = [k for k in lexicon_keys if "ησο" in k.lower()]

    print(f"Candidates in morphology data (containing 'ησο'): {morphology_jesus}")
    for l in morphology_jesus:
        print(f"\n  Morphology lemma {l!r}:")
        print(codepoint_dump(l))

    print(f"\nCandidates in lexicon (containing 'ησο'): {lexicon_jesus}")
    for k in lexicon_jesus:
        print(f"\n  Lexicon key {k!r}:")
        print(codepoint_dump(k))

    if not lexicon_jesus:
        print("\n  NO candidate found in the lexicon at all containing "
              "'ησο' -- this isn't an encoding mismatch, Strong's "
              "dictionary XML may not have an entry for this lemma "
              "under this spelling at all (worth checking manually).")

    print("=" * 70)


if __name__ == "__main__":
    main()