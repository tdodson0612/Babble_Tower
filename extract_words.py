import json, re, sys

data = json.loads(open('/dev/stdin').read())

strip_re = re.compile(r"[^\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036Fa-zA-Z0-9'\s]")
space_re = re.compile(r'\s+')

words = set()
for ch_num, verses in data['chapters'].items():
    for verse in verses:
        text = verse['text']
        cleaned = strip_re.sub('', text.lower())
        cleaned = space_re.sub(' ', cleaned).strip()
        for w in cleaned.split(' '):
            if w and len(w) > 1:
                words.add(w)

# Filter to only Greek words
greek_re = re.compile(r'[\u0370-\u03FF\u1F00-\u1FFF]')
greek_words = sorted([w for w in words if greek_re.search(w)])
print(f"Total unique Greek words: {len(greek_words)}", file=sys.stderr)
print(json.dumps(greek_words, ensure_ascii=False))