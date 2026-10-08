# Test-only fonts (headless stills / goldens)

`flutter_tester` only ships the `FlutterTest` box font, so CJK (and Latin)
text renders as empty boxes ("tofu") in headless PNG stills. These files fix
that **for tests only**.

| File | What |
|---|---|
| `NotoSansCJKtc-Regular.subset.otf` | Noto Sans CJK TC Regular (400), subset |
| `NotoSansCJKtc-Bold.subset.otf` | Noto Sans CJK TC Bold (700), subset |
| `OFL.txt` | SIL Open Font License 1.1 (from the upstream repo) |
| `subset_chars.py` | Rebuilds the subsets (pyftsubset / fonttools) |

- **Font:** Noto Sans CJK TC, **Version 2.004** (Traditional Chinese default
  glyphs; also covers kana and the Japanese forms the game uses, e.g. 突撃).
- **Source:** https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/TraditionalChinese
  (`NotoSansCJKtc-Regular.otf`, `NotoSansCJKtc-Bold.otf`, noto-cjk `main` @ `f8d1575`).
- **License:** SIL OFL 1.1, see `OFL.txt`. Reserved Font Name "Source"
  (Adobe). These are modified (subset) copies, renamed with `.subset`.
- **Subset:** every non-ASCII codepoint found in `lib/**/*.dart` and
  `test/**/*.dart`, plus ASCII, Latin-1, common punctuation and arrows,
  CJK symbols, hiragana/katakana and fullwidth forms (944 codepoints).
  Re-run `python3 test/fonts/subset_chars.py <dir-with-upstream-otfs>` after
  adding new CJK strings.
- **Test-only:** loaded by `test/support/test_fonts.dart` from
  `test/flutter_test_config.dart` via `FontLoader`. The font is **not** listed
  in `pubspec.yaml` `flutter: fonts/assets`, so the shipping app is unchanged.

Registered families: `Roboto` (Material default text in tests, i.e. the
MatchShell HUD), `SangokushiInk` (Flame canvas ink family from PR #9) and
`Noto Sans CJK TC`. Text painted with no `fontFamily` at all still uses
`FlutterTest`; the tester gives no hook to change that default.
