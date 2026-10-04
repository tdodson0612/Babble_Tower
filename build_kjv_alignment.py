#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_kjv_alignment.py

Run from the project root:

    python3 build_kjv_alignment.py

Generates a NEW asset file, assets/alignment/kjv_word_alignment.json,
giving every Greek word occurrence in all four Gospels a second gloss:
the KJV English word(s) that correspond to it IN THAT SPECIFIC VERSE
(as opposed to the existing dictionary, which gives one gloss shared
across every occurrence of a word, regardless of context).

METHOD -- proportional positional partitioning:
There is no word-alignment model available in this environment (no
internet access to download one), so this uses a simpler, honest
heuristic instead of pretending to linguistic precision:

  For a verse with N Greek word-tokens and M KJV English word-tokens,
  the KJV word list is cut into N contiguous slices at positions
  round(i/N * M) for i = 0..N, and Greek token i is assigned slice i.

This guarantees every KJV word is used exactly once, in original
order, with no gaps -- but it is NOT true linguistic alignment. KJV
translators followed Greek word order unusually closely (far more
than a modern paraphrase like NIV would), so this works reasonably
well for straightforward clauses. It will still be visibly wrong in
verses with real reordering, clause restructuring, or heavily
idiomatic/compressed renderings -- e.g. a single Greek participle
that KJV expands into a several-word English clause will have that
whole clause's proportional slice land on ONE Greek word, and the
Greek words around it will look emptier than they should. Treat this
as a best-effort second reference alongside the dictionary gloss, not
a certified linguistic alignment.

Tokenization mirrors the app's own reader exactly: Greek text is
first run through the same USFM-stripping rule as BibleService.
_stripUsfmMarkup, then both Greek and KJV text are split on single
spaces (verse.text.split(' ')), matching verse_block_view.dart.

Output shape (one file, all 4 books):
{
  "matthew": {
    "1": {
      "1": ["Book", "of", "the", "generation", ...]   <- KJV slice
                                                          per Greek
                                                          word, in
                                                          Greek word
                                                          order
    }
  }
}
Each verse's list has exactly as many entries as that verse has Greek
word-tokens (same split rule the app already uses), so the Dart side
can index into it by word position with zero extra matching logic.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GREEK_DIR = ROOT / "assets" / "bible" / "el"
KJV_DIR = ROOT / "assets" / "bible" / "en_kjv"
OUTPUT_DIR = ROOT / "assets" / "alignment"
OUTPUT_PATH = OUTPUT_DIR / "kjv_word_alignment.json"
REPORT_PATH = ROOT / "kjv_alignment_report.json"

# Exact port of BibleService._stripUsfmMarkup (bible_service.dart) --
# Greek source text must go through this before tokenizing, or
# leftover \+w markup would be counted as fake "words".
_USFM_TAG_RE = re.compile(r"\\\+[A-Za-z]+\*?")
_STANDALONE_IT_RE = re.compile(r"\bit\b")
_COLLAPSE_SPACES_RE = re.compile(r"\s+")

# Maps this script's Greek book filenames to the KJV directory's
# filenames -- these differ (ioannis.json vs john.json) per this
# project's existing convention (see bible_service.dart / kjv_service
# .dart's separate _bookFile mappings).
GREEK_TO_KJV_FILE = {
    "matthew": "matthew.json",
    "mark": "mark.json",
    "luke": "luke.json",
    "ioannis": "john.json",
}


def strip_usfm_markup(raw: str) -> str:
    no_tags = _USFM_TAG_RE.sub("", raw)
    no_it = _STANDALONE_IT_RE.sub("", no_tags)
    return _COLLAPSE_SPACES_RE.sub(" ", no_it).strip()


def load_verses(path: Path) -> dict:
    """Returns {chapter_str: {verse_int: text}}."""
    data = json.loads(path.read_text(encoding="utf-8"))
    out = {}
    for chapter_num, verses in data.get("chapters", {}).items():
        out[chapter_num] = {}
        for v in verses:
            out[chapter_num][v["verse"]] = v.get("text", "")
    return out


def partition(kjv_words: list, n: int) -> list:
    """Cuts kjv_words into n contiguous, ordered, non-overlapping
    slices (some may be empty if n > len(kjv_words)), returning each
    slice already joined back into a single display string."""
    m = len(kjv_words)
    if n == 0:
        return []
    cuts = [round(i * m / n) for i in range(n + 1)]
    slices = []
    for i in range(n):
        chunk = kjv_words[cuts[i]:cuts[i + 1]]
        slices.append(" ".join(chunk))
    return slices


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    result = {}
    total_verses = 0
    total_words = 0
    empty_slices = 0

    for greek_path in sorted(GREEK_DIR.glob("*.json")):
        if greek_path.name == "manifest.json":
            continue
        book_key = greek_path.stem
        kjv_filename = GREEK_TO_KJV_FILE.get(book_key)
        if not kjv_filename:
            print(f"WARNING: no KJV mapping for {book_key}, skipping")
            continue
        kjv_path = KJV_DIR / kjv_filename
        if not kjv_path.exists():
            print(f"WARNING: KJV file not found for {book_key} at {kjv_path}, skipping")
            continue

        greek_verses = load_verses(greek_path)
        kjv_verses = load_verses(kjv_path)

        book_out = {}
        for chapter_num, verses in greek_verses.items():
            chapter_out = {}
            kjv_chapter = kjv_verses.get(chapter_num, {})
            for verse_num, greek_text in verses.items():
                cleaned = strip_usfm_markup(greek_text)
                greek_tokens = [t for t in cleaned.split(" ") if t]
                kjv_text = kjv_chapter.get(verse_num, "")
                kjv_tokens = [t for t in kjv_text.split(" ") if t]

                if not greek_tokens:
                    continue

                slices = partition(kjv_tokens, len(greek_tokens))
                chapter_out[str(verse_num)] = slices

                total_verses += 1
                total_words += len(greek_tokens)
                empty_slices += sum(1 for s in slices if not s)

            book_out[chapter_num] = chapter_out
        result[book_key] = book_out
        print(f"{book_key}: {sum(len(v) for v in book_out.values())} verses processed")

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        f.write("\n")

    report = {
        "total_verses": total_verses,
        "total_greek_word_occurrences": total_words,
        "empty_kjv_slices": empty_slices,
        "empty_slice_pct": round(100 * empty_slices / total_words, 2) if total_words else 0,
    }
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print()
    print(f"Total verses processed: {total_verses}")
    print(f"Total Greek word occurrences: {total_words}")
    print(f"Empty KJV slices (Greek words with no aligned KJV text, mostly from verses "
          f"where KJV has fewer words than Greek): {empty_slices} ({report['empty_slice_pct']}%)")
    print(f"Wrote: {OUTPUT_PATH}")
    print(f"Wrote: {REPORT_PATH}")


if __name__ == "__main__":
    main()