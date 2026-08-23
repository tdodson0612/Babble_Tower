#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scan_missing_translations.py

Run from the project root:

    python3 scan_missing_translations.py

Finds every Greek word actually used in the Bible text
(assets/bible/el/*.json) whose translation lookup would fail in the
running app, and reports it — this is a read-only diagnostic, it does
not modify any file.

WHY THIS EXISTS: "some Greek words have no translation" isn't a vague
symptom — it's a real, specific lookup mismatch. Reproduces the EXACT
two-step lookup TappableWord actually performs at runtime
(lib/presentation/widgets/tappable_word.dart -> DictionaryService):

  1. TextNormalizer.normalizeWord(rawToken) — lowercases and strips
     everything except Greek letters, Latin letters, digits, and
     apostrophes (see lib/core/utils/text_normalizer.dart). This is
     the ACTUAL string the app looks up, not the raw verse token.
  2. DictionaryService.lookup does an EXACT key match:
     dict[normalized.lower()] against assets/dictionaries/el_en.json.

The bug: el_en.json's keys were built directly from source verse
tokens, so ~46% of them (5,526 of 12,103 at last count) still carry
attached punctuation, e.g. "αἰγιαλόν·", "(καὶ", "αἰτήσεσθε,". A verse
word normalizes its punctuation away before lookup, but the
dictionary key still has it attached — so unless a SEPARATE, clean
(punctuation-free) key for the same word ALSO exists in the
dictionary, the lookup silently returns null and the reader shows no
translation for a real, valid Greek word.

Tokenization mirrors verse_block_view.dart exactly: verse.text is
split on single spaces (not full whitespace-collapse), matching what
the app actually iterates over per verse.

Output: a JSON report (missing_translations_report.json) listing
every distinct normalized word with no dictionary match, plus one
example raw verse token per word and its Book/chapter/verse
location(s) so each miss can be traced back to real source text.
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BIBLE_DIR = ROOT / "assets" / "bible" / "el"
DICTIONARY_PATH = ROOT / "assets" / "dictionaries" / "el_en.json"
REPORT_PATH = ROOT / "missing_translations_report.json"

# Identical character ranges to lib/core/utils/text_normalizer.dart's
# normalizeWord — do NOT diverge from these ranges, or this script
# stops reproducing the app's actual behavior.
_STRIP_PUNCTUATION = re.compile(
    r"[^\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036Fa-zA-Z0-9']"
)

# Exact port of BibleService._stripUsfmMarkup (bible_service.dart) --
# applied to every verse's raw source text BEFORE it ever becomes
# app-visible content, at load time. This scan reads the raw asset
# JSON directly, bypassing that runtime step, so it MUST replicate
# it here or leftover \+w / \+w* USFM tags and the stray "it" token
# in source files would be misreported as missing translations --
# they're not: the running app never shows that text in the first
# place.
_USFM_TAG_RE = re.compile(r"\\\+[A-Za-z]+\*?")
_STANDALONE_IT_RE = re.compile(r"\bit\b")
_COLLAPSE_SPACES_RE = re.compile(r"\s+")


def strip_usfm_markup(raw: str) -> str:
    """Exact port of BibleService._stripUsfmMarkup (Dart)."""
    no_tags = _USFM_TAG_RE.sub("", raw)
    no_it_marker = _STANDALONE_IT_RE.sub("", no_tags)
    return _COLLAPSE_SPACES_RE.sub(" ", no_it_marker).strip()


def normalize_word(raw: str) -> str:
    """Exact port of TextNormalizer.normalizeWord (Dart)."""
    return _STRIP_PUNCTUATION.sub("", raw.lower())


def load_dictionary() -> dict:
    with open(DICTIONARY_PATH, encoding="utf-8") as f:
        raw = json.load(f)
    # Mirror DictionaryService._load: every key lowercased on load.
    # (Values aren't needed for this scan, just key presence.)
    return {k.lower(): True for k in raw.keys()}


def iter_verse_tokens():
    """Yields (book, chapter, verse_number, raw_token) for every word
    token in every Gospel file, split exactly as
    verse_block_view.dart splits it: verse.text.split(' '), filtering
    empty strings, NOT a general whitespace/regex split."""
    for path in sorted(BIBLE_DIR.glob("*.json")):
        if path.name == "manifest.json":
            continue
        book = path.stem
        data = json.loads(path.read_text(encoding="utf-8"))
        chapters = data.get("chapters", {})
        for chapter_num, verses in chapters.items():
            # Actual asset shape (confirmed against assets/bible/el/
            # matthew.json): chapters[chapter_num] is a LIST of
            # {"verse": int, "text": str} objects -- read the real
            # "verse" field rather than assuming list position, in
            # case any file ever has gaps or out-of-order entries.
            # Handle a dict-keyed-by-verse-number shape too,
            # defensively, since this mirrors BibleService's own
            # defensive posture toward asset shape drift.
            if isinstance(verses, dict):
                verse_items = verses.items()
            else:
                verse_items = (
                    (v.get("verse", i), v) if isinstance(v, dict) else (i, v)
                    for i, v in enumerate(verses, start=1)
                )
            for verse_num, verse_data in verse_items:
                text = None
                if isinstance(verse_data, dict):
                    text = verse_data.get("text", "")
                elif isinstance(verse_data, str):
                    text = verse_data
                if not text:
                    continue
                # Apply the same fix-at-load-time step BibleService
                # applies before this text is ever tokenized/displayed.
                cleaned_text = strip_usfm_markup(text)
                for token in cleaned_text.split(" "):
                    if token:
                        yield book, chapter_num, verse_num, token


def main():
    if not DICTIONARY_PATH.exists():
        print(f"ERROR: dictionary not found at {DICTIONARY_PATH}")
        sys.exit(1)
    if not BIBLE_DIR.exists():
        print(f"ERROR: Bible text directory not found at {BIBLE_DIR}")
        sys.exit(1)

    dictionary_keys = load_dictionary()

    total_tokens = 0
    distinct_words = set()
    # normalized_word -> {"count": int, "example": raw_token,
    #                      "locations": [ "Book chapter:verse", ... ]}
    missing = defaultdict(lambda: {"count": 0, "example": None, "locations": []})

    for book, chapter, verse, raw_token in iter_verse_tokens():
        total_tokens += 1
        normalized = normalize_word(raw_token)
        if not normalized:
            # Punctuation-only token (rare, e.g. a stray dash) — not
            # a real word, nothing to translate, not a bug.
            continue
        distinct_words.add(normalized)

        if normalized in dictionary_keys:
            continue

        entry = missing[normalized]
        entry["count"] += 1
        if entry["example"] is None:
            entry["example"] = raw_token
        location = f"{book} {chapter}:{verse}"
        if len(entry["locations"]) < 5 and location not in entry["locations"]:
            entry["locations"].append(location)

    report = {
        "dictionary_total_keys": len(dictionary_keys),
        "bible_total_word_tokens_scanned": total_tokens,
        "bible_distinct_normalized_words": len(distinct_words),
        "distinct_words_with_no_translation": len(missing),
        "missing_words": {
            word: {
                "occurrences_in_text": data["count"],
                "example_raw_token": data["example"],
                "sample_locations": data["locations"],
            }
            for word, data in sorted(missing.items())
        },
    }

    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Dictionary keys loaded: {len(dictionary_keys)}")
    print(f"Bible word tokens scanned: {total_tokens}")
    print(f"Distinct normalized words in Bible text: {len(distinct_words)}")
    print(f"Distinct words with NO translation match: {len(missing)}")
    if distinct_words:
        pct = 100 * len(missing) / len(distinct_words)
        print(f"  ({pct:.1f}% of all distinct words in the text)")
    print(f"Full report written to: {REPORT_PATH}")


if __name__ == "__main__":
    main()