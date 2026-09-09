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

  /// Session2: enemy aura visible; facing correct after ≥1C.
  bool enemyAuraVisible = false;
  bool facingCorrect = false;
  bool interceptDone = false;
  bool strategyOrReturnDone = false;

  /// Screenshot / debug: jump to clear-pass visuals.
  bool shotPassMode = false;

  void resetToSession1() {
    session = TutorialSession.session1;
    s1 = S1Phase.highlightSelect;
    s2 = S2Phase.spearGlow;
    phaseC = 0;
    tipText = '點選己方騎兵（金色光環）';
    tipSkippable = true;
    failed = false;
    failReason = null;
    auraReady = false;
    enemyAuraVisible = false;
    facingCorrect = false;
    interceptDone = false;
    strategyOrReturnDone = false;
    notifyListeners();
  }

  void resetToSession2() {
    session = TutorialSession.session2;
    s2 = S2Phase.spearGlow;
    phaseC = 0;
    tipText = '槍兵槍尖常駐發光 — 準備迎擊';
    tipSkippable = true;
    failed = false;
    failReason = null;
    enemyAuraVisible = false;
    facingCorrect = false;
    interceptDone = false;
    strategyOrReturnDone = false;
    notifyListeners();
  }

  void skipTip() {
    if (!tipSkippable || tipText == null) return;
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
          tipText = '突擊氣場已滿 — 點浮字「突撃」';
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
          tipText = '再拖到落點，等氣場 ≥1C 再突撃';
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
          tipText = '敵騎突撃氣場出現 — 等 ≥1C 再轉身迎擊';
          notifyListeners();
        }
        break;
      case S2Phase.enemyApproach:
        if (phaseC >= 0.3) {
          phaseC = 0;
          s2 = S2Phase.waitTurn;
          notifyListeners();
        }
        break;
      case S2Phase.waitTurn:
        if (phaseC >= 1.0 && !facingCorrect) {
          facingCorrect = true;
          s2 = S2Phase.interceptHit;
          tipText = '面向正確 — 點「迎擊」';
          notifyListeners();
        }
        break;
      case S2Phase.failRetry:
        if (phaseC >= 0.8) {
          failed = false;
          failReason = null;
          facingCorrect = false;
          enemyAuraVisible = true;
          phaseC = 0;
          s2 = S2Phase.waitTurn;
          tipText = '等氣場 ≥1C、面向正確後再迎擊';
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
    tipText = '拖曳騎兵到落點（勿遮擋底欄）';
    notifyListeners();
  }

  void onDropAtGuide() {
    if (session != TutorialSession.session1 || s1 != S1Phase.dragGuide) return;
    phaseC = 0;
    auraReady = false;
    s1 = S1Phase.waitAura;
    tipText = '蓄力中… 突撃氣場需 ≥1C';
    notifyListeners();
  }

  void onTapCharge() {
    if (session != TutorialSession.session1) return;
    if (s1 == S1Phase.hitCharge && auraReady) {
      s1 = S1Phase.tipNext;
      tipText = '下一場教迎擊';
      tipSkippable = true;
      notifyListeners();
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

  void onTapIntercept({required bool facingWasCorrect}) {
    if (session != TutorialSession.session2) return;
    if (s2 != S2Phase.interceptHit && s2 != S2Phase.waitTurn) return;
    if (facingWasCorrect && facingCorrect) {
      interceptDone = true;
      s2 = S2Phase.strategyOrReturn;
      tipText = '按「計略」或「歸城」完成教學';
      notifyListeners();
    } else {
      failed = true;
      failReason = '面向不對 — 重試';
      phaseC = 0;
      s2 = S2Phase.failRetry;
      tipText = failReason;
      notifyListeners();
    }
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
    tipText = '教學完成 — 接下來選勢力';
    tipSkippable = true;
    notifyListeners();
  }

  /// Force clear-pass UI for Simulator shots.
  void forceSession1Pass() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.tipNext;
    tipText = '下一場教迎擊';
    tipSkippable = true;
    auraReady = true;
    failed = false;
    notifyListeners();
  }

  void forceSession2Pass() {
    shotPassMode = true;
    session = TutorialSession.session2;
    s2 = S2Phase.tipDone;
    tipText = '教學完成 — 接下來選勢力';
    tipSkippable = true;
    interceptDone = true;
    strategyOrReturnDone = true;
    facingCorrect = true;
    enemyAuraVisible = true;
    failed = false;
    notifyListeners();
  }
}
