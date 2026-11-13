# HUD pass against the reference capture — 2026-11-13

Reference frame: `118-S4-COMBAT-01.png` in the 英傑 capture folder on the Air
(`~/Projects/eiketsu-promax-learn-2026-10-16`). The capture is reference-only
and is not copied into this repo.

Three things on that frame the game did not do, now done:

1. **士氣 gauge is a track.** The reference shows every socket, dark until it
   fills, and the next one filling. The HUD bar showed filled pips only, so the
   ceiling and the regen were invisible. It now draws a dark socket for every
   point up to the ceiling (the printed-cost sum, unchanged), and the next
   socket fills as 士氣 recovers.
2. **Castle bars read as HP.** The reference fills both bars green-to-yellow,
   cuts them in four, and keeps the side colour for the frame. Ours were flat
   faction-colour fills. Now: green → yellow → red by HP, four cuts, faction
   colour on the frame.
3. **The clock sits between the bars.** Big, slanted, paper white; red in the
   last 10 C.

Not changed: the 士氣 ceiling and regen rate, castle damage, the fill
direction of either bar, the token cards.

`after.png` is a headless frame (402×874). `after_seam_3x.png` is the seam.
Regenerate: `REFERENCE_HUD_STILLS=1 flutter test test/reference_hud_pass_test.dart`.
