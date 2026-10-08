"""Rebuild the test-only Noto Sans CJK TC subsets in this folder.

Scans lib/ and test/ Dart sources for non-ASCII codepoints, adds ASCII,
Latin-1, kana and common punctuation, and runs pyftsubset (fonttools).

  pip install fonttools
  # download NotoSansCJKtc-{Regular,Bold}.otf (see README.md) into SRC_DIR
  python3 test/fonts/subset_chars.py SRC_DIR
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = pathlib.Path(__file__).resolve().parent

RANGES = [
    (0x0020, 0x007E),  # ASCII
    (0x00A0, 0x00FF),  # Latin-1 (° · × …)
    (0x2010, 0x2027),  # dashes, quotes, ellipsis
    (0x2030, 0x203B),  # ‰ ′ ″ ‹ › ※
    (0x2190, 0x2195),  # arrows
    (0x21D2, 0x21D4),  # ⇒ ⇔
    (0x2212, 0x2212),  # minus
    (0x2248, 0x2248), (0x2260, 0x2260), (0x2264, 0x2265),
    (0x25A0, 0x25CF),  # ■ □ ▲ △ ▼ ○ ● (subset of geometric shapes)
    (0x2605, 0x2606),  # ★ ☆
    (0x3000, 0x303F),  # CJK symbols & punctuation
    (0x3040, 0x30FF),  # hiragana + katakana
    (0xFF01, 0xFF65),  # fullwidth forms
]


def scanned():
    cps = set()
    for sub in ('lib', 'test'):
        for p in (ROOT / sub).rglob('*.dart'):
            cps |= {ord(c) for c in p.read_text(encoding='utf-8') if ord(c) > 0x7E}
    return cps


def main(src_dir):
    cps = scanned()
    for lo, hi in RANGES:
        cps |= set(range(lo, hi + 1))
    unicodes = ','.join(f'U+{c:04X}' for c in sorted(cps))
    for weight in ('Regular', 'Bold'):
        subprocess.run([
            'pyftsubset', str(pathlib.Path(src_dir) / f'NotoSansCJKtc-{weight}.otf'),
            f'--unicodes={unicodes}',
            '--layout-features+=locl,vert,vrt2,halt,palt',
            '--name-IDs=*',
            '--name-legacy',
            '--name-languages=*',
            f'--output-file={OUT / f"NotoSansCJKtc-{weight}.subset.otf"}',
        ], check=True)
    print(f'{len(cps)} codepoints')


if __name__ == '__main__':
    main(sys.argv[1])
