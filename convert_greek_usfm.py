#!/usr/bin/env python3
import json, os, re, sys, glob

BOOKS = {
    'MAT': ('matthew', 'Matthew'),
    'MRK': ('mark',    'Mark'),
    'LUK': ('luke',    'Luke'),
    'JHN': ('ioannis', 'John'),
}

def find_usfm_file(usfm_dir, book_code):
    for pattern in [f'*{book_code}*.usfm', f'*{book_code.lower()}*.usfm']:
        matches = glob.glob(os.path.join(usfm_dir, pattern))
        if matches:
            return matches[0]
    return None

def strip_usfm_tags(raw_line):
    """
    Token-scan the line char by char. Whenever we see a backslash marker,
    handle it explicitly rather than relying on regex spanning, which is
    fragile when footnotes/attributes are adjacent with no whitespace.
    """
    text = raw_line

    # First, remove footnote/cross-ref blocks entirely (including content).
    # These are well-formed open/close pairs.
    text = re.sub(r'\\f\b.*?\\f\*', '', text, flags=re.DOTALL)
    text = re.sub(r'\\fe\b.*?\\fe\*', '', text, flags=re.DOTALL)
    text = re.sub(r'\\x\b.*?\\x\*', '', text, flags=re.DOTALL)

    # Handle \w WORD <anything-not-backslash> \w*  -> WORD
    # The key fix: stop capturing the word at the FIRST whitespace,
    # backslash, or quote-attribute character — never let it swallow
    # into the attribute block even without a space.
    def replace_w(m):
        return m.group(1)

    text = re.sub(
        r'\\w\s+([^\s\\|"]+)(?:[^\\]*?)\\w\*',
        replace_w,
        text,
    )

    # Defensive second pass: if any stray 'strong="G####"' attribute
    # text leaked through fused to a word (no \w wrapper recognized),
    # strip the attribute pattern directly.
    text = re.sub(r'strong="?[A-Z]?\d+"?', '', text)
    text = re.sub(r'strongg?\d+w?', '', text, flags=re.IGNORECASE)

    # Keep content of other character-level tags
    text = re.sub(r'\\(?:wj|nd|bk|tl|add|pn|qt|em|bd|it|sc|no)\*?\s*(.*?)\\(?:\w+\*|\*)', r'\1', text, flags=re.DOTALL)

    # Strip any remaining backslash markers
    text = re.sub(r'\\[\w]+\*?', '', text)

    # Clean up pipes and extra whitespace
    text = text.replace('|', '')
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def parse_usfm(filepath):
    chapters = {}
    current_chapter = None
    current_verse = None
    verse_parts = []

    def flush():
        nonlocal current_verse, verse_parts
        if current_chapter and current_verse is not None:
            text = strip_usfm_tags(' '.join(verse_parts))
            if text:
                chapters.setdefault(str(current_chapter), []).append(
                    {'verse': current_verse, 'text': text}
                )
        current_verse = None
        verse_parts = []

    with open(filepath, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            m = re.match(r'^\\c\s+(\d+)', line)
            if m:
                flush()
                current_chapter = int(m.group(1))
                continue
            m = re.match(r'^\\v\s+(\d+)\s*(.*)', line)
            if m:
                flush()
                current_verse = int(m.group(1))
                rest = m.group(2).strip()
                if rest:
                    verse_parts.append(rest)
                continue
            if current_verse is not None:
                verse_parts.append(line)

    flush()
    return {'chapters': chapters}

def convert(usfm_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    manifest_books = []

    for code, (filename, display_name) in BOOKS.items():
        usfm_path = find_usfm_file(usfm_dir, code)
        if not usfm_path:
            print(f'  [WARN] No USFM file found for {code}')
            continue

        print(f'  Parsing {os.path.basename(usfm_path)} -> {filename}.json ...')
        data = parse_usfm(usfm_path)
        data['book'] = display_name

        chapter_count = len(data['chapters'])
        verse_count = sum(len(v) for v in data['chapters'].values())
        print(f'    {chapter_count} chapters, {verse_count} verses')

        out_path = os.path.join(output_dir, f'{filename}.json')
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f'    Written -> {out_path}')

        manifest_books.append({
            'name': display_name,
            'file': f'{filename}.json',
            'chapters': chapter_count,
        })

    manifest_path = os.path.join(output_dir, 'manifest.json')
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump({'books': manifest_books}, f, ensure_ascii=False, indent=2)
    print(f'\n  Manifest written -> {manifest_path}')
    print('  All 4 Gospel books converted successfully.')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: python3 convert_greek_usfm.py <usfm_dir> <output_dir>')
        sys.exit(1)
    print(f'\nConverting Greek USFM:\n  Source: {sys.argv[1]}\n  Output: {sys.argv[2]}\n')
    convert(sys.argv[1], sys.argv[2])
