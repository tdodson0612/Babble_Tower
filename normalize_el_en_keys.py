#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
normalize_el_en_keys.py

Run from the project root:

    python3 normalize_el_en_keys.py

Fixes the punctuation-mismatch class of missing-translation bugs found
by scan_missing_translations.py: el_en.json's keys were built directly
from source verse tokens, so many carry attached punctuation (e.g.
"αἰτήσεσθε,", "(καὶ", "αἰγιαλόν·"). The reader's real lookup path
(TappableWord -> TextNormalizer.normalizeWord -> DictionaryService
.lookup) strips ALL punctuation before searching, so a punctuated-only
key silently never matches — even though a human-readable translation
for that exact word already exists in the file.

This script:
  1. Reads el_en.json using an object_pairs_hook, so it sees every
     raw (key, value) pair in file order BEFORE Python's json module
     collapses any literal duplicate keys — same technique as
     tools/dedupe_el_en.py, and for the same reason (silent data loss
     on literal dupes is a real, separate bug this also incidentally
     fixes as a side effect of the same merge step below).
  2. Normalizes every key the same way TextNormalizer.normalizeWord
     does (lowercase, strip everything except Greek/Latin letters,
     digits, apostrophes) — an exact port, kept in lockstep with
     scan_missing_translations.py's copy of the same logic.
  3. Groups all raw keys that collapse onto the same normalized key,
     and merges their glosses: split each value on comma, keep every
     DISTINCT meaning-fragment (case-insensitive comparison), in
     order of first appearance across the group (top-to-bottom in
     the file), then join back with ", ". Identical merge rule to
     dedupe_el_en.py, applied here across punctuation variants of
     the same word rather than only literal exact duplicates.

Read-only on the input file — always writes to a NEW output file
(el_en_normalized.json) so the original is untouched until reviewed
and explicitly swapped in.

After running, re-run scan_missing_translations.py against the new
file (see --dict-path note in that script, or copy the output over
assets/dictionaries/el_en.json once satisfied) to confirm the
punctuation-mismatch count has dropped to zero.
"""

import json
import re
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
INPUT_PATH = ROOT / "assets" / "dictionaries" / "el_en.json"
OUTPUT_PATH = ROOT / "el_en_normalized.json"

# Exact port of TextNormalizer.normalizeWord (Dart) — MUST stay in
# lockstep with lib/core/utils/text_normalizer.dart and with
# scan_missing_translations.py's copy of the same regex.
_STRIP_PUNCTUATION = re.compile(
    r"[^\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036Fa-zA-Z0-9']"
)


def normalize_word(raw: str) -> str:
    return _STRIP_PUNCTUATION.sub("", raw.lower())


def collect_raw_pairs(pairs):
    """object_pairs_hook target: just return the raw list, unmodified,
    so literal duplicate keys are visible before any collapsing."""
    return pairs


def merge_glosses(existing: str, new: str) -> str:
    existing_parts = [p.strip() for p in existing.split(",") if p.strip()]
    new_parts = [p.strip() for p in new.split(",") if p.strip()]
    seen_lower = {p.lower() for p in existing_parts}
    combined = list(existing_parts)
    for part in new_parts:
        if part.lower() not in seen_lower:
            combined.append(part)
            seen_lower.add(part.lower())
    return ", ".join(combined)


def main():
    if not INPUT_PATH.exists():
        print(f"ERROR: dictionary not found at {INPUT_PATH}")
        return

    with open(INPUT_PATH, encoding="utf-8") as f:
        raw_pairs = json.load(f, object_pairs_hook=collect_raw_pairs)

    normalized = OrderedDict()
    collisions = 0
    non_string_skipped = 0

    for key, value in raw_pairs:
        if not isinstance(value, str):
            # This dictionary's entries are flat strings in current
            # data; guard defensively rather than guessing how to
            # merge a non-string value if the format ever changes.
            non_string_skipped += 1
            continue

        norm_key = normalize_word(key)
        if not norm_key:
            # A key with no Greek/Latin/digit content at all after
            # stripping (shouldn't happen in practice) — nothing
            # meaningful to look up, skip rather than write an empty
            # key into the output.
            continue

        if norm_key in normalized:
            collisions += 1
            normalized[norm_key] = merge_glosses(normalized[norm_key], value)
        else:
            normalized[norm_key] = value

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(normalized, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")

    print(f"Raw key/value pairs read (incl. literal duplicates): {len(raw_pairs)}")
    print(f"Non-string values skipped: {non_string_skipped}")
    print(f"Keys collapsed into an existing normalized key (merged): {collisions}")
    print(f"Final unique normalized keys written: {len(normalized)}")
    print(f"Wrote: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()