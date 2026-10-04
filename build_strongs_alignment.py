#!/usr/bin/env python3
"""
build_strongs_alignment.py
Aligns KJV text to Greek words using Strong's Concordance numbers.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GREEK_DIR = ROOT / "assets" / "bible" / "el"
KJV_STRONGS_PATH = ROOT / "assets" / "alignment" / "kjv_strongs.json"
OUTPUT_PATH = ROOT / "assets" / "alignment" / "kjv_word_alignment.json"

def clean_strong(tag: str) -> str:
    """Extracts numeric Strong's ID (e.g., 'G1096' -> '1096')."""
    match = re.search(r'\d+', tag)
    return match.group(0) if match else ""

def align_verse_by_strongs(greek_tokens: list, kjv_words_with_strongs: list) -> list:
    """
    greek_tokens: list of dicts with 'text' and 'strong' keys
    kjv_words_with_strongs: list of dicts [{'word': 'made', 'strongs': ['1096']}]
    """
    aligned = [[] for _ in greek_tokens]
    
    for kjv_item in kjv_words_with_strongs:
        word = kjv_item.get("word", "")
        strongs = [clean_strong(s) for s in kjv_item.get("strongs", [])]
        
        # Match KJV word to the corresponding Greek token sharing the same Strong's ID
        matched = False
        for idx, g_token in enumerate(greek_tokens):
            g_strong = clean_strong(g_token.get("strong", ""))
            if g_strong and g_strong in strongs:
                aligned[idx].append(word)
                matched = True
                break
                
    return [" ".join(words) for words in aligned]

print("Strong's alignment script template ready.")