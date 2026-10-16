# Brief 03 — GAP-RET-CASTLE（歸城 / 返城）

Observed foil for the Soft Lock draft. Numbers below are the ones already locked on `uat/softlock-20261008`. This note does not add Official seconds, DPS, or pixel measures.

Cite: `arcade-brief-03-return-revive-2026-10-14` (living 歸城 vs skull 返城). Design plates: `assets/fx/soft-lock-cues/manifest.json` (`fly-guicheng`, `fly-fancheng`, `castle-glow`). Soft Pass #17 (lesson rail, 出城·出征) stays on the tip and is not reopened here.

## Two moves

| | Living 歸城 | Skull 返城 |
|---|---|---|
| Life | stays `alive` | `retreating` → `inCastleReviving` → `readyRedeploy` |
| Enter flash | `fly-guicheng` / 「歸城」 | none (retreat splash stays 「撤退」) |
| Persistent tip | 「返城回血」 while parked and hurt | 「返城」 while the skull is outside the gate |
| Watch | `watch-guicheng` | skull + `watch-fancheng` outside; bar inside |
| Countdown | none | ticks only inside the gate |

Drag into 己城 is the primary path. There is no 歸城 button. The lacquer 計略 seal stays the only seal.

## Castle gate

Wiki band already on the tip: enter `kCastleEnterDepth` 0.60, leave under `kCastleExitDepth` 0.40, band `kCastleBandFracOfField` 0.12. The latch remembers “inside” so a 1px wobble around the lip does not toggle. A body that has left under ~4成 must reach ~6成 again. The geometric band is the drop glow; the gate is the depth test. Parked-in-castle does not count as inside once the body has left the gate.

Finger-down does not 歸城. Release / arrival still parks. 出城準備 is unchanged.

## Countdown and heal

- Morale cost of 撤退 stays `kRetreatMoraleCost` 0.
- Revive base stays Adapted `kReviveBaseSec` 15s. 活／復活 stays × `kReviveSkillMul` (2/3). 桃園 ~35s is not Official.
- Outside the gate, `reviveLeft` does not move. The countdown does not finish in the field and does not auto-charge.
- Living heal stays the existing readable tick `kRansenTickPerSec`. That rate is Unverified — it is not a new DPS number.

## Watch parity

The mirror reads the field the same frame: skull, 「返城」 only while outside, bar only while reviving inside, anchor on the body. Enemies keep the grey mark and do not get this mirror. The living heal plate is not the skull plate.
