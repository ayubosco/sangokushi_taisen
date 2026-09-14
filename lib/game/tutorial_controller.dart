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
    tipText = '先點發光己方騎兵（趙雲），按住拖行去撞敵（跟手指行，唔係瞬移）';
    tipSkippable = false; // cannot tip-skip past drag/collide gate
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
    tipText = '睇住己方槍兵槍尖光（常在）；敵騎氣勢撞到槍尖就自動迎擊';
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
    // Soft-fix: tips must NOT skip drag+aura/collide gate (no charge/intercept buttons).
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
          tipText = '光環穩晒 — 拖行撞敵就自動突撃（唔使撳掣）';
          tipSkippable = false; // tip alone cannot pass without prior drag/collide
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
          tipText = '再嚟過：按住拖行累積光環，撞敵就自動突撃';
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
          tipText = '敵騎氣勢出咗 — 唔好急，等氣勢撞到槍尖就自動迎擊';
          // ignore: avoid_print
          print('VERIFY_S2 auraVisible phaseC=$phaseC');
          notifyListeners();
        }
        break;
      case S2Phase.enemyApproach:
        if (phaseC >= 0.3) {
          phaseC = 0;
          s2 = S2Phase.waitTurn;
          tipText = '仲要等陣… 槍尖光常在，等敵氣勢夠撞尖';
          notifyListeners();
        }
        break;
      case S2Phase.waitTurn:
        // Aura must stay visible ≥1C before player may turn facing / intercept.
        if (phaseC >= 1.0 && !turnWindowOpen) {
          turnWindowOpen = true;
          tipText = '夠喇！敵氣勢撞到槍尖 — 自動迎擊';
          tipSkippable = false;
          facingCorrect = true; // tip always on toward threat
          // ignore: avoid_print
          print('VERIFY_S2 turnWindowOpen phaseC=$phaseC');
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
          tipText = '再嚟過：等敵氣勢撞到槍尖就自動迎擊';
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
    tipText = '按住拖行：部隊跟手指走，行路累積光環，撞敵就自動突撃';
    notifyListeners();
  }

  void onDropAtGuide() {
    // Legacy FEEL/shot helper — live play uses onChargeTravelProgress (walk distance).
    if (session != TutorialSession.session1 || s1 != S1Phase.dragGuide) return;
    phaseC = 0;
    auraReady = false;
    didDragDrop = true;
    s1 = S1Phase.waitAura;
    tipText = '繼續拖行… 光環靠行路距離累積，鬆手就停喺原位';
    tipSkippable = false;
    notifyListeners();
  }

  /// Arcade: charge aura fills from continuous walk distance (0..1). No teleport.
  void onChargeTravelProgress(double dist01) {
    if (session != TutorialSession.session1) return;
    if (s1 != S1Phase.dragGuide && s1 != S1Phase.waitAura && s1 != S1Phase.hitCharge) {
      return;
    }
    if (shotPassMode) return;
    final d = dist01.clamp(0.0, 1.0);
    if (d >= 1.0) {
      if (!auraReady || s1 != S1Phase.hitCharge) {
        auraReady = true;
        didDragDrop = true;
        s1 = S1Phase.hitCharge;
        tipText = '光環夠喇 — 繼續拖行去撞敵就自動突撃（唔使撳掣）';
        tipSkippable = false;
        notifyListeners();
      }
      return;
    }
    if (s1 == S1Phase.dragGuide && d > 0.12) {
      s1 = S1Phase.waitAura;
      tipText = '跟住手指拖行累積氣勢… 鬆手就停，唔會瞬移';
      tipSkippable = false;
      notifyListeners();
    } else if (s1 == S1Phase.waitAura) {
      final pct = (d * 10).floor() * 10; // 0/10/20… tip throttle
      final next = '繼續拖行… 氣勢 $pct% — 夠咗再撞敵';
      if (tipText != next) {
        tipText = next;
        notifyListeners();
      }
    }
  }

  /// Auto charge after drag/collide + aura ≥1C — no floating「突撃」button.
  void onAutoCharge() {
    if (session != TutorialSession.session1) return;
    if (s1 == S1Phase.hitCharge && auraReady && didDragDrop) {
      s1 = S1Phase.tipNext;
      tipText = '撞中自動突撃！場1過關 — 撳「跳過」入教學場2：迎擊';
      tipSkippable = true;
      notifyListeners();
      return;
    }
    if (!didDragDrop &&
        (s1 == S1Phase.highlightSelect ||
            s1 == S1Phase.dragGuide ||
            s1 == S1Phase.waitAura ||
            s1 == S1Phase.hitCharge)) {
      _failS1('未拖到位 — 拖去撞敵／落點、等光環夠先過關');
      return;
    }
    if (s1 == S1Phase.waitAura || s1 == S1Phase.dragGuide || s1 == S1Phase.hitCharge) {
      _failS1('仲未夠／時機唔啱 — 再嚟過');
    }
  }

  @Deprecated('Use onAutoCharge — charge button removed')
  void onTapCharge() => onAutoCharge();

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
      _failS2('太早喇 — 等敵氣勢夠先郁');
      return;
    }
    if (facingCorrect) return;
    facingCorrect = true;
    s2 = S2Phase.interceptHit;
    tipText = '槍尖朝敵 — 氣勢撞尖就自動迎擊';
    tipSkippable = false;
    notifyListeners();
  }

  /// Auto intercept when enemy aura hits spear tip — no floating「迎擊」button.
  void onAutoIntercept({required bool facingWasCorrect}) {
    if (session != TutorialSession.session2) return;
    if (s2 != S2Phase.interceptHit &&
        s2 != S2Phase.waitTurn &&
        s2 != S2Phase.enemyApproach &&
        s2 != S2Phase.spearGlow) {
      return;
    }
    if (!turnWindowOpen) {
      _failS2('嚟唔切 — 等敵氣勢撞到槍尖');
      return;
    }
    if (facingWasCorrect && facingCorrect) {
      interceptDone = true;
      s2 = S2Phase.strategyOrReturn;
      tipText = '迎擊成功！撳右下「計略」，或拖返己城帶';
      tipSkippable = false;
      notifyListeners();
    } else {
      _failS2('槍尖未對敵 — 等氣勢撞尖先');
    }
  }

  @Deprecated('Use onAutoIntercept — intercept button removed')
  void onTapIntercept({required bool facingWasCorrect}) =>
      onAutoIntercept(facingWasCorrect: facingWasCorrect);

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
    tipText = '教學搞掂！撳「跳過」去選勢力';
    tipSkippable = true;
    notifyListeners();
  }

  /// Force clear-pass UI for Simulator shots.
  void forceSession1Pass() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.tipNext;
    tipText = '撞中自動突撃！場1過關 — 撳「跳過」入教學場2：迎擊';
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
    tipText = '教學搞掂！撳「跳過」去選勢力';
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
    tipText = '拖到落點／撞敵喇：光環亮晒 — 會自動突撃';
    tipSkippable = false; // soft-fix: tip cannot skip drag/collide
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
    tipText = '撳右下「計略」，或拖返己城帶搞掂';
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
    // Mid continuous travel foreshadow — rings on before full fill.
    s1 = S1Phase.waitAura;
    phaseC = 0.7;
    auraReady = false;
    didDragDrop = true;
    tipText = '行路中氣勢光環 — 場同 Watch 都要見青白環';
    tipSkippable = false;
    failed = false;
    notifyListeners();
  }

  void forceChargeAuraLive() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.waitAura;
    phaseC = 0.7;
    auraReady = false;
    didDragDrop = true;
    tipText = '連續拖行中 — 青白氣場環（未滿亦要見）';
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
    tipText = '拖去落點（跟住拖線）— 未見光環唔好撞';
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
    tipText = '突撃中！場1過關（拖到位、氣勢夠）';
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
    tipText = '敵氣勢出咗 — 等夠晒撞槍尖就自動迎擊（槍尖光常在）';
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
    tipText = '槍尖光常在；敵氣勢撞尖就自動迎擊';
    tipSkippable = false;
    failed = false;
    notifyListeners();
  }

  /// Feel shot: stratagem FX, board tappable (strategyOrReturn).
  void forceFeelStratagem() {
    forceSession2Coach();
  }
}
