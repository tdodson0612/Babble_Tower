#!/usr/bin/env python3
"""
build_morphology.py

Phase 10 data pipeline. Run from the project root:

    python3 build_morphology.py

Downloads MorphGNT (tags the SBLGNT critical text) and aligns it against
this app's Byzantine Majority Text (assets/bible/el/*.json) on a per-verse
basis. Only verses where the BMT word count exactly matches the MorphGNT
word count for that verse are kept — this is a deliberate correctness
choice, not a shortcut: SBLGNT and BMT are different textual traditions,
and a naive index join would silently mis-tag words in verses with textual
variants. Misaligned verses are skipped entirely (logged, not tagged) —
the app will simply not offer grammar-parsing questions for those verses.

Output: assets/morphology/{matthew,mark,luke,ioannis}.json
Each file mirrors the shape of assets/bible/el/*.json:
    {"chapters": {"1": {"1": [ {word,pos,parse,lemma}, ... ], "2": [...] }}}
Only chapters/verses that aligned are present.

Re-run this any time the BMT text files change — output is fully
regenerated, not merged.
"""

import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BIBLE_DIR = ROOT / "assets" / "bible" / "el"
OUT_DIR = ROOT / "assets" / "morphology"
CACHE_DIR = ROOT / ".morphgnt_cache"

# Same Greek-letter range the app uses everywhere else.
# NEVER \w — see handoff doc, "Greek regex" critical rule.
GREEK_WORD_RE = re.compile(r"[\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036F]+")

MORPHGNT_BASE = "https://raw.githubusercontent.com/morphgnt/sblgnt/master"

# app book key -> (BMT filename, MorphGNT filename)
BOOKS = {
    "matthew": ("matthew.json", "61-Mt-morphgnt.txt"),
    "mark":    ("mark.json",    "62-Mk-morphgnt.txt"),
    "luke":    ("luke.json",    "63-Lk-morphgnt.txt"),
    "ioannis": ("ioannis.json", "64-Jn-morphgnt.txt"),
}


def fetch_morphgnt(filename: str) -> str:
    CACHE_DIR.mkdir(exist_ok=True)
    cached = CACHE_DIR / filename
    if cached.exists():
        return cached.read_text(encoding="utf-8")
    url = f"{MORPHGNT_BASE}/{filename}"
    print(f"  downloading {url}")
    with urllib.request.urlopen(url) as resp:
        text = resp.read().decode("utf-8")
    cached.write_text(text, encoding="utf-8")
    return text


def parse_morphgnt(text: str) -> dict:
    """Returns {(chapter, verse): [ {pos, parse, word, lemma}, ... ]}."""
    by_verse: dict = {}
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) < 7:
            continue
        bcv, pos, parse, _word_punct, word_no_punct, _normalized, lemma = fields[:7]
        chapter = int(bcv[2:4])
        verse = int(bcv[4:6])
        by_verse.setdefault((chapter, verse), []).append({
            "pos": pos,
            "parse": parse,
            "word": word_no_punct,
            "lemma": lemma,
        })
    return by_verse


def load_bmt(bmt_filename: str) -> dict:
    """Returns {(chapter, verse): [greek_token, ...]} tokenized the same
    way the app does (extract_words style), preserving BMT surface forms
    (accents, breathing marks, elision) so quiz text matches exactly."""
    raw = json.loads((BIBLE_DIR / bmt_filename).read_text(encoding="utf-8"))
    by_verse = {}
    for chapter_str, verses in raw.get("chapters", {}).items():
        chapter = int(chapter_str)
        for v in verses:
            verse_num = v["verse"]
            tokens = GREEK_WORD_RE.findall(v["text"])
            by_verse[(chapter, verse_num)] = tokens
    return by_verse


def align_book(book_key: str, bmt_filename: str, morphgnt_filename: str) -> dict:
    print(f"Aligning {book_key}...")
    morphgnt_text = fetch_morphgnt(morphgnt_filename)
    morphgnt_verses = parse_morphgnt(morphgnt_text)
    bmt_verses = load_bmt(bmt_filename)

    aligned_chapters: dict = {}
    total = 0
    aligned = 0

    for (chapter, verse), bmt_tokens in bmt_verses.items():
        total += 1
        mg_entries = morphgnt_verses.get((chapter, verse))
        if mg_entries is None or len(mg_entries) != len(bmt_tokens):
            continue  # misaligned — skip silently, per chosen strategy

        aligned += 1
        words = [
            {
                "word": bmt_token,          # BMT surface form — matches verse text exactly
                "pos": mg["pos"],
                "parse": mg["parse"],
                "lemma": mg["lemma"],
            }
            for bmt_token, mg in zip(bmt_tokens, mg_entries)
        ]
        aligned_chapters.setdefault(str(chapter), {})[str(verse)] = words

    pct = (aligned / total * 100) if total else 0
    print(f"  {aligned}/{total} verses aligned ({pct:.1f}%)")
    return {"chapters": aligned_chapters}, total, aligned


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    grand_total = 0
    grand_aligned = 0

    for book_key, (bmt_filename, morphgnt_filename) in BOOKS.items():
        data, total, aligned = align_book(book_key, bmt_filename, morphgnt_filename)
        grand_total += total
        grand_aligned += aligned
        out_path = OUT_DIR / bmt_filename
        out_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"  wrote {out_path}")

    pct = (grand_aligned / grand_total * 100) if grand_total else 0
    print(f"\nTotal: {grand_aligned}/{grand_total} verses aligned ({pct:.1f}%)")
    print("Done. Add assets/morphology/ to pubspec.yaml assets: if not already listed.")


if __name__ == "__main__":
    main()