import 'package:flutter/foundation.dart';

/// W2 two-session tutorial state machine (C-tick driven externally via [tick]).
enum TutorialSession { session1, session2, complete }

enum S1Phase {
  highlightSelect,
  dragGuide,
  waitAura,
  hitCharge,
  failRetry,
  tipNext,
  passed,
}

enum S2Phase {
  spearGlow,
  enemyApproach,
  waitTurn,
  interceptHit,
  failRetry,
  strategyOrReturn,
  tipDone,
  passed,
}

class TutorialController extends ChangeNotifier {
  TutorialController({this.startSession = TutorialSession.session1});

  TutorialSession startSession;
  TutorialSession session = TutorialSession.session1;
  S1Phase s1 = S1Phase.highlightSelect;
  S2Phase s2 = S2Phase.spearGlow;

  /// Accumulated C since current wait started (1C ≈ 3.03s).
  double phaseC = 0;
  String? tipText;
  bool tipSkippable = true;
  bool failed = false;
  String? failReason;

  /// Session1: aura armed after ≥1C on drop.
  bool auraReady = false;

  /// Session2: enemy aura visible; after aura ≥1C turn window opens for manual facing.
  bool enemyAuraVisible = false;
  /// True once enemy aura has been visible ≥1C — player may change facing then intercept.
  bool turnWindowOpen = false;
  bool facingCorrect = false;
  bool interceptDone = false;
  bool strategyOrReturnDone = false;

  /// Screenshot / debug: jump to clear-pass visuals.
  bool shotPassMode = false;

  /// Soft-fix: charge pass requires drag-to-drop + aura≥1C (not tip-skip alone).
  bool didDragDrop = false;

  void resetToSession1() {
    session = TutorialSession.session1;
    s1 = S1Phase.highlightSelect;
    s2 = S2Phase.spearGlow;
    phaseC = 0;
    tipText = '而家做：點金色光環嘅己方騎兵（趙雲）— 點中後要拖去落點';
    tipSkippable = false; // cannot tip-skip past drag gate
    failed = false;
    failReason = null;
    auraReady = false;
    didDragDrop = false;
    enemyAuraVisible = false;
    turnWindowOpen = false;
    facingCorrect = false;
    interceptDone = false;
    strategyOrReturnDone = false;
    notifyListeners();
  }

  void resetToSession2() {
    session = TutorialSession.session2;
    s2 = S2Phase.spearGlow;
    phaseC = 0;
    tipText = '而家做：睇住己方槍兵槍尖發光，等敵騎氣場出現再迎擊';
    tipSkippable = false;
    failed = false;
    failReason = null;
    enemyAuraVisible = false;
    turnWindowOpen = false;
    facingCorrect = false;
    interceptDone = false;
    strategyOrReturnDone = false;
    notifyListeners();
  }

  void skipTip() {
    if (!tipSkippable || tipText == null) return;
    // Soft-fix: tips like「點突撃過關」must NOT skip drag+aura gate.
    if (session == TutorialSession.session1 &&
        (s1 == S1Phase.highlightSelect ||
            s1 == S1Phase.dragGuide ||
            s1 == S1Phase.waitAura ||
            s1 == S1Phase.hitCharge ||
            s1 == S1Phase.failRetry)) {
      return;
    }
    if (session == TutorialSession.session2 &&
        (s2 == S2Phase.spearGlow ||
            s2 == S2Phase.enemyApproach ||
            s2 == S2Phase.waitTurn ||
            s2 == S2Phase.interceptHit ||
            s2 == S2Phase.failRetry ||
            s2 == S2Phase.strategyOrReturn)) {
      return;
    }
    tipText = null;
    if (session == TutorialSession.session1 && s1 == S1Phase.tipNext) {
      s1 = S1Phase.passed;
      resetToSession2();
      return;
    }
    if (session == TutorialSession.session2 && s2 == S2Phase.tipDone) {
      s2 = S2Phase.passed;
      session = TutorialSession.complete;
      tipText = null;
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  /// Advance phase timers; [dtSeconds] wall time → C via / 3.03.
  void tick(double dtSeconds) {
    if (shotPassMode) return;
    phaseC += dtSeconds / 3.03;

    if (session == TutorialSession.session1) {
      _tickS1();
    } else if (session == TutorialSession.session2) {
      _tickS2();
    }
  }

  void _tickS1() {
    switch (s1) {
      case S1Phase.waitAura:
        if (phaseC >= 1.0 && !auraReady) {
          auraReady = true;
          s1 = S1Phase.hitCharge;
          tipText = '青白環已亮！而家點浮字「突撃」過關（要拖過先）';
          tipSkippable = false; // tip alone cannot pass without prior drag
          notifyListeners();
        }
        break;
      case S1Phase.failRetry:
        if (phaseC >= 0.8) {
          failed = false;
          failReason = null;
          auraReady = false;
          phaseC = 0;
          s1 = S1Phase.dragGuide;
          tipText = '重試：拖向落點（金圈），等青白環亮起再點「突撃」';
          tipSkippable = false;
          didDragDrop = false;
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  void _tickS2() {
    switch (s2) {
      case S2Phase.spearGlow:
        if (phaseC >= 0.4) {
          phaseC = 0;
          s2 = S2Phase.enemyApproach;
          enemyAuraVisible = true;
          tipText = '敵騎氣場出咗 — 用 HUD 數 ≥1C，唔好太早迎擊';
          notifyListeners();
        }
        break;
      case S2Phase.enemyApproach:
        if (phaseC >= 0.3) {
          phaseC = 0;
          s2 = S2Phase.waitTurn;
          tipText = '氣場可見中… 數 ≥1C 先轉面（點己方槍兵）';
          notifyListeners();
        }
        break;
      case S2Phase.waitTurn:
        // Aura must stay visible ≥1C before player may turn facing / intercept.
        if (phaseC >= 1.0 && !turnWindowOpen) {
          turnWindowOpen = true;
          tipText = '轉身窗開！點己方槍兵轉面迎敵，再點「迎擊」';
          tipSkippable = false;
          notifyListeners();
        }
        break;
      case S2Phase.failRetry:
        if (phaseC >= 0.8) {
          failed = false;
          failReason = null;
          facingCorrect = false;
          turnWindowOpen = false;
          enemyAuraVisible = true;
          phaseC = 0;
          s2 = S2Phase.waitTurn;
          tipText = '重試：等氣場 ≥1C → 點槍兵轉面 → 再點「迎擊」';
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  void onSelectOwnCavalry() {
    if (session != TutorialSession.session1) return;
    if (s1 != S1Phase.highlightSelect && s1 != S1Phase.dragGuide) return;
    s1 = S1Phase.dragGuide;
    tipText = '拖向敵騎方向落點（金圈），等青白環亮起再突撃';
    notifyListeners();
  }

  void onDropAtGuide() {
    if (session != TutorialSession.session1 || s1 != S1Phase.dragGuide) return;
    phaseC = 0;
    auraReady = false;
    didDragDrop = true;
    s1 = S1Phase.waitAura;
    tipText = '蓄力中… 等青白環亮起（≥1C）再點「突撃」';
    tipSkippable = false;
    notifyListeners();
  }

  void onTapCharge() {
    if (session != TutorialSession.session1) return;
    // Cannot pass by tip-button alone: need drag drop + aura ≥1C.
    if (s1 == S1Phase.hitCharge && auraReady && didDragDrop) {
      s1 = S1Phase.tipNext;
      tipText = '場1過關！撳「跳過」進入教學場2：迎擊';
      tipSkippable = true;
      notifyListeners();
      return;
    }
    if (!didDragDrop &&
        (s1 == S1Phase.highlightSelect ||
            s1 == S1Phase.dragGuide ||
            s1 == S1Phase.waitAura ||
            s1 == S1Phase.hitCharge)) {
      _failS1('未拖到落點 — 要拖＋氣場≥1C 先過關');
      return;
    }
    // Too early / wrong timing
    if (s1 == S1Phase.waitAura || s1 == S1Phase.dragGuide || s1 == S1Phase.hitCharge) {
      _failS1('氣場未滿或時機不對 — 重試');
    }
  }

  void _failS1(String reason) {
    failed = true;
    failReason = reason;
    phaseC = 0;
    s1 = S1Phase.failRetry;
    tipText = reason;
    notifyListeners();
  }

  /// Player taps own spear to change facing once turn window is open.
  void onTapTurnFacing() {
    if (session != TutorialSession.session2) return;
    if (s2 != S2Phase.waitTurn && s2 != S2Phase.interceptHit) return;
    if (!turnWindowOpen) {
      _failS2('太早轉面／迎擊 — 敵氣場要可見 ≥1C');
      return;
    }
    if (facingCorrect) return;
    facingCorrect = true;
    s2 = S2Phase.interceptHit;
    tipText = '面向正確！而家點浮字「迎擊」過關';
    tipSkippable = false;
    notifyListeners();
  }

  void onTapIntercept({required bool facingWasCorrect}) {
    if (session != TutorialSession.session2) return;
    if (s2 != S2Phase.interceptHit &&
        s2 != S2Phase.waitTurn &&
        s2 != S2Phase.enemyApproach &&
        s2 != S2Phase.spearGlow) {
      return;
    }
    // Too early: aura not yet visible ≥1C.
    if (!turnWindowOpen) {
      _failS2('嚟唔切 — 敵氣場要可見 ≥1C 先迎擊');
      return;
    }
    if (facingWasCorrect && facingCorrect) {
      interceptDone = true;
      s2 = S2Phase.strategyOrReturn;
      tipText = '而家做：撳右下「計略」或左「歸城」完成教學';
      tipSkippable = false;
      notifyListeners();
    } else {
      _failS2('面向不對 — 先點槍兵轉面再迎擊');
    }
  }

  void _failS2(String reason) {
    failed = true;
    failReason = reason;
    phaseC = 0;
    s2 = S2Phase.failRetry;
    tipText = reason;
    notifyListeners();
  }

  void onStrategy() {
    if (session != TutorialSession.session2 || s2 != S2Phase.strategyOrReturn) return;
    if (!interceptDone) return;
    strategyOrReturnDone = true;
    _passS2();
  }

  void onReturnCity() {
    if (session != TutorialSession.session2 || s2 != S2Phase.strategyOrReturn) return;
    if (!interceptDone) return;
    strategyOrReturnDone = true;
    _passS2();
  }

  void _passS2() {
    s2 = S2Phase.tipDone;
    tipText = '教學完成！撳「跳過」去選勢力';
    tipSkippable = true;
    notifyListeners();
  }

  /// Force clear-pass UI for Simulator shots.
  void forceSession1Pass() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.tipNext;
    tipText = '場1過關！撳「跳過」進入教學場2：迎擊';
    tipSkippable = true;
    auraReady = true;
    didDragDrop = true;
    failed = false;
    notifyListeners();
  }

  void forceSession2Pass() {
    shotPassMode = true;
    session = TutorialSession.session2;
    s2 = S2Phase.tipDone;
    tipText = '教學完成！撳「跳過」去選勢力';
    tipSkippable = true;
    interceptDone = true;
    strategyOrReturnDone = true;
    facingCorrect = true;
    turnWindowOpen = true;
    enemyAuraVisible = true;
    failed = false;
    notifyListeners();
  }

  /// Simulator: 場1 オーラ ≥1C gate — frozen waitAura with charge rings ready.
  void forceSession1AuraGate() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.waitAura;
    phaseC = 1.0;
    auraReady = true;
    didDragDrop = true; // shot assumes prior drag
    tipText = '拖到落點後：青白環已亮（≥1C）— 點「突撃」';
    tipSkippable = false; // soft-fix: tip「點突撃過關」cannot skip drag
    failed = false;
    failReason = null;
    notifyListeners();
  }

  /// Simulator: 場2 槍尖常駐＋計略 FX — tip strategyOrReturn, board stays tappable.
  void forceSession2Coach() {
    shotPassMode = true;
    session = TutorialSession.session2;
    s2 = S2Phase.strategyOrReturn;
    phaseC = 1.0;
    tipText = '而家做：撳右下「計略」或左「歸城」完成教學';
    tipSkippable = false;
    interceptDone = true;
    strategyOrReturnDone = false;
    facingCorrect = true;
    turnWindowOpen = true;
    enemyAuraVisible = true;
    failed = false;
    failReason = null;
    notifyListeners();
  }

  /// Feel shot: drag guide + bright aura on own + enemy visible on field.
  void forceFeelDragAura() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.hitCharge;
    phaseC = 1.0;
    auraReady = true;
    didDragDrop = true;
    tipText = '拖有導線／落點；青白環≥1C 先撞';
    tipSkippable = false;
    failed = false;
    notifyListeners();
  }

  /// Feel shot: mid-drag rubber-band (guide line) before aura — tip cannot skip.
  void forceFeelDragLive() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.dragGuide;
    phaseC = 0;
    auraReady = false;
    didDragDrop = false;
    tipText = '拖向落點（導線）— 未見環唔撞；tip 唔跳拖';
    tipSkippable = false;
    failed = false;
    failReason = null;
    notifyListeners();
  }

  /// Feel shot: post-hit 突撃 after drag + aura≥1C.
  void forceFeelDragHit() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.tipNext;
    phaseC = 1.0;
    auraReady = true;
    didDragDrop = true;
    tipText = '突撃命中！場1過關（拖＋氣場≥1C）';
    tipSkippable = true;
    failed = false;
    failReason = null;
    notifyListeners();
  }

  /// Feel shot: intercept wait window — enemy aura visible, turn window not yet / just open, facing still wrong.
  void forceFeelInterceptWindow() {
    shotPassMode = true;
    session = TutorialSession.session2;
    s2 = S2Phase.waitTurn;
    phaseC = 0.85; // mid-wait: aura on, count toward ≥1C
    facingCorrect = false;
    turnWindowOpen = false;
    enemyAuraVisible = true;
    interceptDone = false;
    tipText = '敵オーラ可見 — 數 ≥1C 先轉面迎擊（槍尖常在）';
    tipSkippable = false;
    failed = false;
    failReason = null;
    notifyListeners();
  }

  /// Feel shot: intercept tip glow + facing ready (hit pose).
  void forceFeelIntercept() {
    shotPassMode = true;
    session = TutorialSession.session2;
    s2 = S2Phase.interceptHit;
    phaseC = 1.0;
    facingCorrect = true;
    turnWindowOpen = true;
    enemyAuraVisible = true;
    interceptDone = false;
    tipText = '槍尖常在；敵オーラ≥1C 後轉面迎擊';
    tipSkippable = false;
    failed = false;
    notifyListeners();
  }

  /// Feel shot: stratagem FX, board tappable (strategyOrReturn).
  void forceFeelStratagem() {
    forceSession2Coach();
  }
}
