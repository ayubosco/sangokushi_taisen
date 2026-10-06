# Soft polish P1/P2 (post-Feel)

Design Gate Soft notes on the Pass stills at Feel `f45c034`. Layout only. Damage numbers, life states, and the 突撃→亂戰 timing are unchanged. No new TARGET frames.

## What changed

1. **R1** — The retreat life tip is placed just under the 「撤退」 splash (`kRetreatTipClearance`) so 「散咗拖返城先復活」 stays readable during the freeze.
2. **R2** — 「落點」 is kept inside the canvas. The grey castle card keeps a bottom strip (`kLandingLabelReserve`) so the label is not cut by the screen edge.
3. **CAV** — On body contact the player's card paints after the enemy and steps aside (`kContactOwnCardShiftXFrac` / `kContactOwnCardShiftYFrac`). Gameplay centers, the charge ring, 「突撃」, and 「亂戰」 stay on the true overlap.

## Why

The Gate Pass stills (simctl R1, R2, CAV) were readable enough to pass, with three non-blocking notes: the splash covered half the tip, the castle 「落點」 was clipped, and the own cavalry card disappeared under the enemy card at contact.

## How to verify

Unit and golden sequences (no device):

```
flutter test test/retreat_revive_test.dart test/retreat_revive_visual_verify_test.dart
flutter test test/troop_retreat_path_test.dart test/troop_retreat_visual_verify_test.dart
```

Those cover UnitLife R1–R4 (splash, tip, castle countdown) and troop retreat by type (CAV 突撃 drop, CAVK 突撃 retreat, SPEAR 迎擊, BOW 射, INF 亂戰, SIEGE 城傷).

Later stills use the same defines as the Feel gate. Compare them by eye to the existing ref frames. Do not invent a new TARGET.

```
flutter run --dart-define=RETREAT_REVIVE_VISUAL_VERIFY=true
flutter run --dart-define=TROOP_RETREAT_VISUAL_VERIFY=true
```
