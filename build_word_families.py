#!/usr/bin/env python3
"""
build_word_families.py

Phase 12 data pipeline. Run from the project root:

    python3 build_word_families.py

Source: morphgnt/strongs-dictionary-xml (CC0 / public domain) — the same
GitHub organization Phase 10's build_morphology.py already pulls from.
Each entry's <strongs_derivation> contains structured <strongsref> child
elements pointing to the Strong's number(s) it derives from — this is
real relational data, not prose we'd have to guess-parse.

This does NOT depend on your BMT text or dictionary files — it's a
self-contained lexicon keyed by the Strong's dictionary's own citation
spelling. The app looks up a word's *lemma* (already captured per-word
in assets/morphology/*.json by Phase 10 — see ParsingWord.lemma) against
this table at runtime. Caveat: MorphGNT lemma spelling and this
dictionary's citation spelling usually match exactly (both use standard
accented citation forms) but aren't guaranteed to for every entry —
treat a lookup miss as "no family data for this word," not an error,
the same fail-safe posture Phase 10 takes for alignment misses.

Output: assets/word_families/lexicon.json
    { "ἀγάπη": {"strongs": "26", "gloss": "...",
                 "derivesFrom": ["ἀγαπάω"], "derivedForms": [...]} }
Only lemmas with at least one relation (derivesFrom OR derivedForms) are
included — an isolated word with no known relatives isn't a "family."
"""

import json
import re
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT_DIR = ROOT / "assets" / "word_families"
CACHE_DIR = ROOT / ".strongs_cache"

STRONGS_URL = (
    "https://raw.githubusercontent.com/morphgnt/strongs-dictionary-xml"
    "/master/strongsgreek.xml"
)


def fetch_xml() -> str:
    CACHE_DIR.mkdir(exist_ok=True)
    cached = CACHE_DIR / "strongsgreek.xml"
    if cached.exists():
        return cached.read_text(encoding="utf-8")
    print(f"  downloading {STRONGS_URL}")
    with urllib.request.urlopen(STRONGS_URL) as resp:
        text = resp.read().decode("utf-8")
    cached.write_text(text, encoding="utf-8")
    return text


def clean_text(elem) -> str:
    """Flattens an element's text content (including nested <greek>,
    <strongsref>, etc.) into a single readable string, collapsing
    whitespace. Used for the gloss (strongs_def), never for parsing
    relations — those come from the structured strongsref elements."""
    text = "".join(elem.itertext())
    return re.sub(r"\s+", " ", text).strip(" ;:.")


def _pad(strongs_num: str) -> str:
    """Normalizes a Strong's number to the same 5-digit zero-padded form
    used for <entry strongs="..."> keys. <strongsref strongs="..."> uses
    UNPADDED numbers (e.g. "25" vs the entry key "00025") — without this,
    every single derivesFrom/derivedForms cross-reference silently fails
    to resolve, producing entries that look populated (the raw relation
    was detected) but whose actual output arrays are empty."""
    return strongs_num.zfill(5)


# This 1890s-sourced XML (prepared 2006) encodes accented vowels using the
# older Unicode "oxia" codepoints (Greek Extended block, U+1F00-1FFF —
# the polytonic-tradition accent mark), e.g. U+1F71 for ά. MorphGNT/SBLGNT
# and this app's own BMT text use the standard "tonos" codepoints (main
# Greek block, U+0370-03FF), e.g. U+03AC for the SAME visible character.
# These look byte-for-byte identical on screen but are different
# codepoints, so a raw string match between this dictionary's lemma and
# any MorphGNT lemma silently fails 100% of the time without this map —
# exactly how ἀγάπη (oxia) and ἀγάπη (tonos) failed to match in testing.
_OXIA_TO_TONOS = str.maketrans({
    "\u1f71": "\u03ac",  # ά
    "\u1f73": "\u03ad",  # έ
    "\u1f75": "\u03ae",  # ή
    "\u1f77": "\u03af",  # ί
    "\u1f79": "\u03cc",  # ό
    "\u1f7b": "\u03cd",  # ύ
    "\u1f7d": "\u03ce",  # ώ
})


def normalize_accents(text: str) -> str:
    return text.translate(_OXIA_TO_TONOS)


def parse_entries(xml_text: str) -> dict:
    """Returns {strongs_number: {"lemma": ..., "gloss": ...,
    "derivesFrom": [strongs_number, ...]}}. All Strong's numbers —
    dict keys and derivesFrom values alike — are zero-padded via [_pad],
    so every value in this dict is directly usable as a key into it."""
    root = ET.fromstring(xml_text)
    entries = {}
    for entry in root.find("entries").findall("entry"):
        num = _pad(entry.get("strongs"))
        greek = entry.find("greek")
        if greek is None:
            continue  # a handful of entries are Hebrew/Aramaic-only
        lemma = normalize_accents(greek.get("unicode"))

        gloss_elem = entry.find("strongs_def")
        gloss = clean_text(gloss_elem) if gloss_elem is not None else ""

        derives_from = []
        deriv_elem = entry.find("strongs_derivation")
        if deriv_elem is not None:
            for ref in deriv_elem.findall(".//strongsref"):
                if ref.get("language") == "GREEK":
                    derives_from.append(_pad(ref.get("strongs")))

        entries[num] = {"lemma": lemma, "gloss": gloss, "derivesFrom": derives_from}
    return entries


def build_lexicon(entries: dict) -> dict:
    # Invert derivesFrom to get derivedForms (children) per Strong's number.
    derived_forms: dict = {num: [] for num in entries}
    for num, data in entries.items():
        for parent_num in data["derivesFrom"]:
            if parent_num in derived_forms:
                derived_forms[parent_num].append(num)

    lexicon = {}
    for num, data in entries.items():
        if not data["derivesFrom"] and not derived_forms[num]:
            continue  # isolated word — no family to show

        derives_from_lemmas = [
            entries[p]["lemma"] for p in data["derivesFrom"] if p in entries
        ]
        derived_forms_lemmas = [
            entries[c]["lemma"] for c in derived_forms[num] if c in entries
        ]

        lexicon[data["lemma"]] = {
            "strongs": num,
            "gloss": data["gloss"],
            "derivesFrom": derives_from_lemmas,
            "derivedForms": derived_forms_lemmas,
        }
    return lexicon


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    xml_text = fetch_xml()
    entries = parse_entries(xml_text)
    lexicon = build_lexicon(entries)

    out_path = OUT_DIR / "lexicon.json"
    out_path.write_text(
        json.dumps(lexicon, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"  {len(entries)} total entries parsed")
    print(f"  {len(lexicon)} lemmas have at least one family relation")
    print(f"  wrote {out_path}")


if __name__ == "__main__":
    main()