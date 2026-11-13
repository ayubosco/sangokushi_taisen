# DONE — Taisen Soft Lock · Soft polish ×3 (2026-10-30)

Taisen. Soft Pass ≠ Feel. Feel CLOSED (no device, no Simulator). Soft Pass / Soft Gate claim eye = Product Lead; this file does not self-claim a pass.

## Tip
- Base: draft #42 `softlock/claude-sge05-bow10` @ `cf0770c7f087ead5bde0f9894aa8af1aaf9d5bf3` (confirmed = PR head)
- Branch: `softlock/claude-soft-polish-x3`
- Code tip: `730e76ac32089ca5522c9e4f0f402ebdfc8b309b` (this DONE.md lands one commit after it)
- `flutter analyze`: no issues. `flutter test`: 291 passed, 2 skipped (pre-existing skips), 0 failed.
- New suite: `test/soft_polish_x3_test.dart` (9 tests).

## P1 — R1 tip under 撤退
- The 返城 tip on a retreating own skull now sits **below the skull card** (below the cause line when one shows).
- Its top is at least `kRetreatTipGapPx = 8` below the measured 「撤退」 splash box (`retreatSplashRect`). In practice the gap is much larger.
- It sits below the card bottom, so the HP bar and number above the card never cover it.
- It is clamped whole inside the field (left/right/bottom). The old `_drawText` maxWidth wrap near the right edge can no longer clip it.
- Sprite `fly-fancheng` (56×33) uses the same box. The ink text fallback is centred on the token.
- The slot does not move when the 1s splash decays.
- Tests: mid-field gap ≥8 and on-field; right-edge token fully on-screen; slot stable after the splash decays.

## P2 — R2 落點 label
- **Reviving in 己城 with the pin up:** 「落點」 draws **inside the grey card, under the centred timer**, and the below-pin label is skipped. Headless 402×746: label `189,727.9 → 213,743.9`, card fully on-screen.
- **Retreating skull walking to the pin** (no pin card): the label sits **above the pin card top**, clamped to the field. Headless: `665.5 → 681.5`, pin near the band bottom.
- **Alive pin:** unchanged. The full-colour 落點釘 card still covers the label as before.
- Tests: walking label bottom ≤ pin card top and inside the field; reviving label inside the face rect, below its centre, and bottom ≤ screen.

## P3 — CAV contact card stack
- Picked the **attacker-above** option. A 「突撃」 flash paints the attacker last for `kContactTopSec = 0.4s` (inside 0.3–0.5), then field order returns.
- 迎擊 and 氣勢 do not reorder.
- Cyan is unchanged: the punch ring uses one shared `debugPunchCyanRadius` (≤ `1.5 × token width`), still clipped by `_fieldFxClip`.
- Tests:
  - the window constant is in range;
  - order is [1,0] during the window and [0,1] after;
  - other splashes keep [0,1];
  - the real `TroopRetreatVisualVerify` CAV contact frame has own cavalry last;
  - punch cyan ≤ 1.5 tokens.

## Open Qs (Product Lead)
1. P1 places the tip under the card, not directly under the splash on the card face. On the face it would cover the 骷 glyph and the HP chrome. Is that position OK, or should the tip hug the splash (≥8 gap) and overlap the card?
2. P2: headless, the pin clears on arrival before the countdown ticks, so the stock R2 hold usually shows no 落點 label at all. The in-card placement covers the device frames where the pin is still up. Is that the frame Product Lead saw?
3. P3: attacker-above only, no X offset. With the verify's full-overlap stack, the defender face returns after 0.4s. Add the slight X offset as well?
4. Pre-existing, untouched: a retreating skull that is **pinned and walking** draws the 影子行軍 path and no 返城 tip.

## Not done (Scope OUT honoured)
No themes 2–4, Feel, Simulator, device install, official mul, clash-fx / token-v2 wire, merges, or undrafting. Regenerated `artifacts/lookalike-lk-*` stills were not committed.
