# AUTH-GAP — 英傑 戰鬥教學 stages 1–5 (2026-10-16)

Soft Lock tip: `uat/softlock-20261008` @ `7371788` (lesson rail + 弓 after aimed 迎撃).
Foil: Pro Max physical learn of 三國英傑大戦 Ch1 戰鬥教學, same day. Every arcade claim below is **Observed-from-英傑** (dialogue, tips, and one still readout). None of those readouts is a locked number. This pass does not retune damage, range, morale costs, or layout.

Soft Lock Feel stays **CLOSED**. This is not a Feel Pass. Drafts #15 / #9 / #7 / #8 / #10 / #18 stay HOLD.

Hypothesis check, verified in this tree:

| Claim | Verdict |
|---|---|
| 槍擊 arms when the spear **changes direction**, then lasts until it hits | **Missing.** Facing only aims the tip. |
| 弓兵 loses its shot when it enters 亂戰 | **Already true.** Move also cancels the draw. |
| 計略 spends a 士氣 cost | **Missing.** The seal is a ≤1C Watch FX. |

## What already matches

Qualitative only. Playtest stubs (`kRansenTickPerSec`, `kRansenMaxHp`, burst seconds) are not arcade DPS.

- **Split board.** Read-only Watch over a drag field, plus a 計略 control outside the field. Flame watch is `kWatchFractionOfGame` = 0.125 of the game widget (`lib/game/taisen_game.dart`). H0 still wants Watch ≤20% of the full screen and the drag field ≥55% (`docs/design-layout-proportion-h0.md`). The foil reads top ~1/3 3D and bottom ~2/3 自陣/敵陣. Those proportions are not the same lock, and this pass does not move them.
- **Drag order.** Finger sets a waypoint; the body pursues. Session 1 tip is drag own cavalry into the enemy. Matches the foil’s yellow-path drag (輕騎兵 → 城門, 刀兵 card → 城門, 槍兵 → 騎兵).
- **快馬突擊.** Cavalry builds 突撃 only after `kChargeTravelNeed` (120px). Contact with a lit aura fires 突撃 once, then the pair stays in 亂戰 (`_fireChargeHit`, `_tickRansen`). Matches the foil tip 「騎兵前進一定距離後會發動突擊 / 突擊可造成強勁傷害」. No new travel length.
- **槍頭 vs a fast cavalry, as a contact gate.** `_tickSpearTips`: tip reached × (aura or wiki speed > `kInterceptSpeedMin` 1.3) × target front 180° → one 「迎擊」. A cavalry victim loses a full playtest bar; other troops lose one tick unless speed ≥ `kDoubleInterceptSpeed` 2.0, which doubles that stub. Wiki +40 is explicitly not applied. A slow (≤1.3, no aura) or rear scrape is a light 「槍尖」 tick, not 迎撃 (`test/softlock_gap_not_pass_test.dart`, `test/spear_intercept_brief01_test.dart`). This is the same *lesson* as 「騎兵撞到槍兵的槍頭會受到大量傷害」 and 「槍頭能對高速移動的敵人造成更多傷害」. It is not 槍擊 (next section).
- **刀兵 / 步.** `TroopType.infantry` has no charge and no tip. Overlap is mutual 亂戰 (`_ransenOutgoingPerSec`). Matches 「刀兵無兵種特性，只能發動亂戰」. There is no extra 「以武力壓制敵方兵種優勢」 bonus.
- **弓 standing fire.** `_tickBowStanding`: stopped bow auto-locks a living enemy inside `_bowRangePx` (half the field; px called Unverified in code) and looses after the still windup. A drag cancels the draw (`_bowIsMoving`). Matches 「弓兵會自動瞄準射程內的敵人」 and 「移動時難以拉弓射箭」. The foil gave no range in px, so the half-field stub stays.
- **亂戰 turns specialties off.** Overlap retracts the spear tip (`spearTipExtendedAt`), drops a live cavalry aura, and cancels bow windup so `_releaseBowShot` does not fire (`_suppressRansenActions`, `test/ransen_meter_test.dart`). That is the bow half of 「雙方武將過於接近便會進入亂戰…避免兵種特性失效」. It is suppression of the existing action, not a new status name.
- **計略 data on the card face only.** `CardFace.strategyMorale` and `intel` are display fields. The detail sheet prints 「士氣 N」 (`lib/ui/card_detail_sheet.dart`). 赤壁の大火’s effect string already says damage follows 知力. Nothing in the match reads those fields.

## Gaps

### 1. 槍擊-on-turn — missing

Observed-from-英傑, stage 3 槍擊退敵:

- 「轉槍，舉起槍頭，使出槍擊迎擊退敵。」
- 「槍兵在改變方向時能發動槍擊，造成致命一擊。」
- 「槍頭金光正盛，那就是槍擊。」 The glow is the armed state, not the idle spear.
- 「槍擊狀態將會持續到擊中敵軍為止。」
- 「回頭，讓他撞上槍擊自滅吧。」 Cavalry that crashes into an armed 槍擊 is the fatal hit.
- Cue shape: a short reverse drag, then a new path into the cavalry. One still showed a 3450 popup after 迎擊. That figure is a single readout, not a formula, and it is **not** adopted.

Soft Lock (`_tickSpearTips`, `_aimSelectedSpearNow`, `TutorialController.onSpearAimedByMove`):

- Changing facing writes `_travelFacing` / `_cardFacing` so the tip points along the finger.
- The big hit is computed from the **target’s** aura or speed at the moment the tip arrives. It does not set a flag on the spear.
- The tip glow is on whenever the tip is extended (`spearTipExtendedAt`: off in 亂戰, 歸城, siege prep). There is no second “gold until hit” state.
- After the hit, `_tipResolved` clears when the tip leaves that body. Nothing persists across a whiff.
- The lesson tells the player to face the enemy and wait for the aura to hit the tip. It does not teach a reverse drag as the arming input.

Do not add a 槍擊 multiplier, a persist timer, or a new fly string in this pass. The contact 迎撃 gate stays.

### 2. 槍兵 vs 騎兵 — partial

Matched: fast or aura cavalry on the front of the tip takes the heavy 迎撃; a slow bump does not.

Not the same rule:

- 英傑 arms 槍擊 on the spear’s own turn, then any crash into that state is the fatal (stage 3, including 「更多的騎兵」 after the turn).
- Soft Lock will 迎撃 a cavalry that is already fast when it reaches the tip, even if the spear never reversed. A spear that reverses in open ground arms nothing (`test/auth_gap_eiketsu_2026_10_16_test.dart`).
- Non-cavalry “high speed” is only the >1.3 gate plus a ×2 stub at ≥2.0. There is no separate speed-scaled spearhead table. Do not invent one from the 3450 readout.
- Foil contrast: 刀兵 can 擊破 a 槍兵 in melee, while cavalry into the spearhead takes the heavy hit. Soft Lock 亂戰 is a mutual chip, and body overlap retracts the tip, so the spearhead counter and the infantry mash are different states. That split is already coded. The missing piece is the armed 槍擊, not a new infantry DPS.

### 3. 弓兵遠攻 — melee loss is in; archer siege is not

Matched (see above): auto-aim in range, no shot while moving, no shot in 亂戰.

Missing, Observed-from-英傑, stage 4 遠攻削敵:

- 「速派單一弓兵攻城。」 One archer on the enemy gate shows 「攻城中」 and a countdown; 「另一弓兵從後支援」.
- Soft Lock prep is `TroopType.siege` only (`_tickSiegePrep`). A bow standing in `enemyCastleZoneRect` does not fill the gauge and does not nick the castle (`test/auth_gap_eiketsu_2026_10_16_test.dart`). A spear in that zone is already locked the same way (`test/siege_prep_gauge_test.dart`).
- 「輪流走位牽制，方可奇策制勝」 is a kiting lesson. The Soft Lock bow tip says stay still and do not drag (`TutorialController.onSelectBow` / `onBowShot`). The rail does not teach alternating positions.

`_bowRangePx` stays the unverified half-field. The foil did not measure a range.

### 4. 計略 / 士氣 / 雷擊 / 智力 — missing as combat

Observed-from-英傑, stage 5 用計得宜:

- 「武將能釋放特殊的計略。計略按類型可造成不同效果。」
- 「擁有計略的武將可消耗下方士氣值釋放計略。」 The hex bar is 士氣. Teaching cards showed a blue cost (謀士 6, 槍/騎 2). Those are card readouts, not a roster table.
- 「士氣欄高亮提示計略所需士氣值。士氣值會隨時間回復。」
- 「選取武將會顯示其計略範圍。」 Cast path: flick-up on the card, or drag from the card onto the map unit (beam).
- 「例如武將謀士便可使出雷擊。」 「雷擊的效果受雙方智力差距影響。差距越大，雷擊便越有效。」 Teaching cards read 謀士 智力 6 against troop 智力 2. Not a formula.
- Result line: 「敵軍大破，軍心大亂。」 士氣 dropped on the cast (about 6 → about 2 on that still). Not a regen rate.

Soft Lock:

- `triggerStrategyFx` places a ≤1C Watch burst (`FxWindows.strategyFxMaxC`) and does not change `matchMorale`.
- `matchMorale` only moves by `kRetreatMoraleCost`, which is 0. Retreat does not spend 士氣 either.
- `TutorialController.onStrategy`: on the live 回城 step the tip is 「計略得，但場2要拖返歸城區先過關」. 計略 does not clear the lesson. The rail is 騎突擊 → 槍迎撃 → 弓教學 → 回城. There is no 用計得宜 step.
- No 計略範圍 preview, no card→map cast, no 雷擊, no 智力差, no morale regen, no 「軍心大亂」.

Cost6 `strategyMorale` values (2–7 on the roster) are copy from the card source notes. They are not the teaching-card 6/2, and `triggerStrategyFx` does not read them. Do not overwrite the roster to match one tutorial still.

### 5. Lesson list — different chapter, left as-is

Observed-from-英傑 stage list:

1. 逐一擊破
2. 快馬突擊
3. 槍擊退敵
4. 遠攻削敵
5. 用計得宜 — the bottom button read 開戰; earlier stages read 開始

Soft Lock rail (`TutorialController.lessons`): 騎突擊, 槍迎撃, 弓教學, 回城. No knife-vs-knife 逐一擊破, no 槍擊 lesson, no 用計得宜. 回城 is the closer. Rebuilding that rail is a Feel lesson change (#17 just locked the 弓 handoff). Not in this pass.

Other foil notes that are not combat rules and are not implemented here: stack counts on one token (4 輕騎兵, 3 長槍兵), deploying a hand card onto 自陣城門 as a separate order from a field drag, and the victory / 章節選擇 shell.

## Files

| Topic | Where |
|---|---|
| 迎撃 gate, not 槍擊 | `lib/game/taisen_game.dart` `_tickSpearTips`, `_aimSelectedSpearNow` |
| Tip glow vs 亂戰 | `spearTipExtendedAt` |
| Bow auto / move / 亂戰 | `_tickBowStanding`, `_suppressRansenActions` |
| Siege is siege-troop only | `_tickSiegePrep`, `debugSiegePrepVisible` |
| 士氣 stub | `matchMorale`, `kRetreatMoraleCost`, `triggerStrategyFx` |
| 計略 is not the pass | `lib/game/tutorial_controller.dart` `onStrategy`, `lessons` |
| Card 士氣 / 知力 text | `lib/data/card_models.dart`, `lib/ui/card_detail_sheet.dart` |
| Locks for this gap | `test/auth_gap_eiketsu_2026_10_16_test.dart` |

## Still needs Bosco Feel GO

Feel stays closed until Bosco says otherwise. Offline, do not:

- Add a 槍擊 armed-until-hit state, gold-tip FX, or any damage number (including 3450).
- Spend 士氣, draw a 計略範圍, or cast 雷擊 from the seal. Card-flick and card→map are Feel UI.
- Let a bow run 「攻城中」, or rewrite the four-step rail into the five 英傑 stages.
- Retune Watch / field to the foil’s ~1/3 / ~2/3, or lock `_bowRangePx` from this learn (no measured range).
- Treat teaching-card costs (6 and 2) or 智力 6 vs 2 as formulas.
