#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dedupe_el_en.py

Run from wherever el_en.json actually lives (project root or
assets/dictionaries/, wherever you point it):

    python3 dedupe_el_en.py el_en.json el_en_deduped.json

Fixes a real, silent data-loss bug: JSON syntax technically allows the
same key to appear more than once in an object, but standard parsers
(Dart's json.decode included) just keep the LAST occurrence and throw
every earlier one away with no warning. If el_en.json has entries like:

    "λόγῳ": "divine utterance, analogy",
    "λόγῳ": "a word, speech",

...then every time this file has ever been loaded, only "a word,
speech" was ever actually used — "divine utterance, analogy" was
silently discarded at parse time, every single time.

This script uses Python's json.load with a custom object_pairs_hook,
which is the one clean way to see EVERY duplicate before any of them
get collapsed into a dict — far safer than regex/sed against a 12,000-
line file full of commas, quotes, and Greek Unicode.

Merge rule: for duplicate keys, split each value on comma, keep every
DISTINCT meaning-fragment (case-insensitive comparison so "God" and
"god" count as the same), in order of first appearance across the
duplicates (top-to-bottom in the file), then join back with ", ".

Read-only on your input file — always writes to a NEW output file, so
your original is untouched until you're satisfied with the result.
"""

import json
import sys
from collections import OrderedDict


def merge_duplicate_keys(pairs):
    merged = OrderedDict()
    duplicate_count = 0

    for key, value in pairs:
        if key not in merged:
            merged[key] = value
            continue

        duplicate_count += 1
        if not isinstance(value, str) or not isinstance(merged[key], str):
            # Non-string values (shouldn't happen in this dictionary's
            # flat-string format, but guard anyway) — just keep the
            # first one seen rather than guessing how to merge them.
            continue

        existing_parts = [p.strip() for p in merged[key].split(',') if p.strip()]
        new_parts = [p.strip() for p in value.split(',') if p.strip()]

        seen_lower = {p.lower() for p in existing_parts}
        combined = list(existing_parts)
        for part in new_parts:
            if part.lower() not in seen_lower:
                combined.append(part)
                seen_lower.add(part.lower())

        merged[key] = ', '.join(combined)

    merged['__duplicate_count__'] = duplicate_count
    return merged


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 dedupe_el_en.py <input.json> <output.json>")
        sys.exit(1)

    input_path, output_path = sys.argv[1], sys.argv[2]

    with open(input_path, encoding='utf-8') as f:
        data = json.load(f, object_pairs_hook=merge_duplicate_keys)

    duplicate_count = data.pop('__duplicate_count__', 0)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')

    print(f"Input entries (including duplicates): counted during merge")
    print(f"Duplicate key occurrences merged: {duplicate_count}")
    print(f"Final unique keys written: {len(data)}")
    print(f"Wrote: {output_path}")
    if duplicate_count > 0:
        print()
        print(f"⚠️  {duplicate_count} duplicate key occurrences were found and "
              f"merged. Before this script, every one of those was silently "
              f"losing data on every app load — this is a real fix, not just "
              f"cosmetic.")


if __name__ == '__main__':
    main()