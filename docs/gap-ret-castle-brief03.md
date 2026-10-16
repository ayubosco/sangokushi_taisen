# GAP-RET-CASTLE — Brief 03 parity notes

**Date:** 2026-10-16
**Base:** `uat/softlock-20261008` @ `7371788`
**Scope:** offline Soft Lock. Feel is closed. Merge stays on hold.

Source is `arcade-brief-03-return-revive-2026-10-14.md` (Locked / Wiki / Adapted). The living heal rate in that brief is **Unverified**. This pass does not invent a castle DPS, a new revive length, or a new gate depth. The Watch bar's pixel size is a paint stand-in so the fill can be read. It is not an Official measure.

## Two moves

| Move | Who | Cue | Result |
| --- | --- | --- | --- |
| 歸城 | Living unit | One-shot 「歸城」 (`fly-guicheng`), then persistent 「返城回血」 while healing | Sit and heal. No skull. No revive bell. |
| 撤退 → 復活 | Skull after HP 0 | Persistent 「返城」 (`fly-fancheng`) while outside the gate | Countdown runs only inside the gate |

Living heal must not reuse the skull plate. Drag into the own castle stays the primary path. There is no 「歸城」 button (`floatingActionHitRect` stays empty) so it cannot stack on 計略.

## Castle gate

The wiki hysteresis already on the tip is unchanged:

- Castle band `kCastleBandFracOfField` = 0.12
- Enter `kCastleEnterDepth` = 0.60 (~6成)
- Leave `kCastleExitDepth` = 0.40 (~4成)

`_castleInside` is the sticky bit `castleGateContains` writes. A fresh body needs ~6成 to count as inside. Once inside, it stays until depth drops under ~4成. The next entry needs ~6成 again. `fieldInCastle` is the parked flag (heal and 出城). It is not a substitute for the gate, and being in the reviving state is not a permanent inside flag.

One pixel short of 0.60 does not start the countdown. One pixel past it does. The exact 0.40 line is left as it already is: the exit check uses `<= 0.40`, and the gate uses `>= 0.40`.

## Watch parity

`WatchReviveMirror` is the live skull read, the same frame as the field:

- Outside: `watch-skull` + `watch-fancheng`. No bar. `reviveLeft` stays frozen.
- In-castle reviving: `watch-skull` + `watch-revive` equal to that frame's `reviveLeft`. No 「返城」.
- Ready to leave: skull only. No bar, no 「返城」.
- Living heal: `watch-guicheng`. Never `watch-fancheng`.
- An enemy skull stays a grey circle. It is not mirrored.

The anchor moves with the body through the existing Watch map. The 26×4 bar is only so the shrinking fill is visible. It is not a new pixel lock.

## Left as they already are

- Morale cost of 撤退 = 0
- Revive base 15s. 活／復活 ×2/3. 桃園 ~35s is not cited as Official.
- Heal reuses `kRansenTickPerSec` (the playtest stub). Unverified. Not a new number.
- H0 chrome, tip length, CHG-10 travel, RET-09, and Brief 02 standing bow are untouched.
- Countdown end does not auto-charge or auto-walk.

## Band glow

A selected own skull whose tip is 「返城」 lights the castle band. A living drag whose waypoint sits in the geometric band lights it while the body is still walking. That read only turns the flag on, so a still that already set it stays lit. Parking turns it off.
