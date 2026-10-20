import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

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
  /// Soft Lock Field1: stand bow → 蓄勢 → 射 (after a geometry 槍 Pass).
  bowTeach,
  /// Soft Lock Field1: drag own into 歸城區 (after 弓). Was strategyOrReturn either/or.
  returnCity,
  /// 英傑 stage 5 用計得宜: preview the caster's range, then cast and spend
  /// the printed 士氣. The cast clears the tutorial (after 回城).
  strategyTeach,
  /// Shot / legacy alias for [returnCity] stratagem stills.
  strategyOrReturn,
  tipDone,
  passed,
}

/// Ordered Soft Lock handoff. Locked steps stay named — the player can read
/// the next lesson before it opens. Names follow the 英傑 戰鬥教學 stage list
/// (快馬突擊 / 槍擊退敵 / 遠攻削敵 / 用計得宜). 回城 is a Soft Lock step with
/// no 英傑 stage. No stamina cost and no cut-in.
enum TutorialLessonGate { locked, current, done }

class TutorialLesson {
  const TutorialLesson({
    required this.id,
    required this.name,
    required this.gate,
  });

  final String id;
  final String name;
  final TutorialLessonGate gate;

  bool get unlocked => gate != TutorialLessonGate.locked;
  bool get current => gate == TutorialLessonGate.current;
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

  /// Order the player can always read:
  /// 快馬突擊 → 槍擊退敵 → 遠攻削敵 → 回城 → 用計得宜.
  /// Only the current step is playable. The next step hard-unlocks on Pass.
  /// 弓 stays locked until one aimed 迎撃 — a wait timer does not open it.
  /// 用計得宜 is the closer, as in the 英傑 stage list.
  List<TutorialLesson> get lessons {
    final bowOpen = bowLessonUnlocked;
    final spearPlayable = session == TutorialSession.session2 ||
        (session == TutorialSession.session1 &&
            (s1 == S1Phase.tipNext || s1 == S1Phase.passed));
    final returnOpen = _returnLessonOpen;
    final strategyOpen = _strategyLessonOpen;
    return [
      TutorialLesson(
        id: 'charge',
        name: '快馬突擊',
        gate: session == TutorialSession.session1 &&
                s1 != S1Phase.tipNext &&
                s1 != S1Phase.passed
            ? TutorialLessonGate.current
            : TutorialLessonGate.done,
      ),
      TutorialLesson(
        id: 'spear',
        name: '槍擊退敵',
        gate: bowOpen || session == TutorialSession.complete
            ? TutorialLessonGate.done
            : (spearPlayable ? TutorialLessonGate.current : TutorialLessonGate.locked),
      ),
      TutorialLesson(
        id: 'bow',
        name: '遠攻削敵',
        gate: !bowOpen
            ? TutorialLessonGate.locked
            : (s2 == S2Phase.bowTeach ? TutorialLessonGate.current : TutorialLessonGate.done),
      ),
      TutorialLesson(
        id: 'return',
        name: '回城',
        gate: !returnOpen
            ? TutorialLessonGate.locked
            : (strategyOpen ? TutorialLessonGate.done : TutorialLessonGate.current),
      ),
      TutorialLesson(
        id: 'strategy',
        name: '用計得宜',
        gate: !strategyOpen
            ? TutorialLessonGate.locked
            : (s2 == S2Phase.strategyTeach
                ? TutorialLessonGate.current
                : TutorialLessonGate.done),
      ),
    ];
  }

  /// 弓教學 is on the queue after a geometry-clear aimed 迎撃, including the
  /// steps that follow it. Idle contact and the ≥1C wait do not set this.
  bool get bowLessonUnlocked {
    if (!interceptDone) return false;
    if (session != TutorialSession.session2 && session != TutorialSession.complete) {
      return false;
    }
    switch (s2) {
      case S2Phase.bowTeach:
      case S2Phase.returnCity:
      case S2Phase.strategyTeach:
      case S2Phase.strategyOrReturn:
      case S2Phase.tipDone:
      case S2Phase.passed:
        return true;
      default:
        return false;
    }
  }

  /// Live 弓 lesson. Standing fire and bow select use this, not a clock.
  bool get bowLessonLive => bowLessonUnlocked && s2 == S2Phase.bowTeach;

  bool get _returnLessonOpen {
    if (session == TutorialSession.complete) return true;
    if (session != TutorialSession.session2 || !interceptDone) return false;
    switch (s2) {
      case S2Phase.returnCity:
      case S2Phase.strategyTeach:
      case S2Phase.strategyOrReturn:
      case S2Phase.tipDone:
      case S2Phase.passed:
        return true;
      default:
        return false;
    }
  }

  /// 用計得宜 opens only after 回城. The shot-only either/or gate
  /// ([S2Phase.strategyOrReturn]) does not open it.
  bool get _strategyLessonOpen {
    if (session == TutorialSession.complete) return true;
    if (session != TutorialSession.session2 || !interceptDone) return false;
    switch (s2) {
      case S2Phase.strategyTeach:
      case S2Phase.tipDone:
      case S2Phase.passed:
        return true;
      default:
        return false;
    }
  }

  /// Live 用計得宜. The seal, flick, and card→map cast clear it.
  bool get strategyLessonLive => _strategyLessonOpen && s2 == S2Phase.strategyTeach;

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
    tipText = '場2槍教學：拖槍轉方向，槍頭金光留到打中；槍尖對住敵先迎擊';
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
            s2 == S2Phase.bowTeach ||
            s2 == S2Phase.returnCity ||
            s2 == S2Phase.strategyTeach ||
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
        // Travel-distance model owns aura (onChargeTravelProgress).
        // Do NOT promote via wall-clock ≥1C — that fought fade-on-stop and
        // spam-notified every frame after release (phaseC already high).
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
          tipText = '敵騎氣勢出咗 — 準備拖槍兵對住敵（槍尖光常在）';
          // ignore: avoid_print
          print('VERIFY_S2 auraVisible phaseC=$phaseC');
          notifyListeners();
        }
        break;
      case S2Phase.enemyApproach:
        if (phaseC >= 0.3) {
          phaseC = 0;
          s2 = S2Phase.waitTurn;
          tipText = '仲要等陣… 槍尖光常在；夠鐘就拖槍對敵';
          notifyListeners();
        }
        break;
      case S2Phase.waitTurn:
        // Aura must stay visible ≥1C before player may MOVE-aim tip / intercept.
        if (phaseC >= 1.0 && !turnWindowOpen) {
          turnWindowOpen = true;
          tipText = '夠喇！拖槍兵向敵騎 — 槍尖對住就迎擊（唔好淨等）';
          tipSkippable = false;
          // Soft Lock: facingCorrect only after MOVE aim — never auto-pass.
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
          tipText = '再嚟過：拖槍兵向敵，槍尖對住先迎擊';
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
    _notifyUi();
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


  /// Safe notify: Flame may call us from GameWidget layout/build.
  /// Coalesce post-frame callbacks so deferred tips never drop / spam.
  /// Travel/aura game paint must NOT depend on this — only Flutter tip/HUD.
  bool _notifyUiScheduled = false;

  void _notifyUi() {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        _notifyUiScheduled = false;
        notifyListeners();
        return;
      }
      if (_notifyUiScheduled) return;
      _notifyUiScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyUiScheduled = false;
        notifyListeners();
      });
    } catch (_) {
      // Binding not ready (tests) or exotic phase — never throw into Flame update.
      _notifyUiScheduled = false;
      notifyListeners();
    }
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
        tipText = '氣勢 — 光環亮咗，繼續拖行撞敵就自動突撃';
        tipSkippable = false;
        _notifyUi();
      }
      return;
    }
    if (s1 == S1Phase.dragGuide && d > 0.12) {
      s1 = S1Phase.waitAura;
      tipText = '蓄緊 ${(d * 100).round()}% — 未亮唔好撞';
      tipSkippable = false;
      _notifyUi();
    } else if (s1 == S1Phase.waitAura) {
      final pct = (d * 10).floor() * 10; // 0/10/20… tip throttle
      final next = '蓄緊 $pct%';
      if (tipText != next) {
        tipText = next;
        _notifyUi();
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
      _notifyUi();
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

  /// Soft Lock Field1: MOVE aims the tip. Tap alone does not grant facing.
  /// Early tap (before turn window) still fails so the ≥1C gate stays readable.
  void onTapTurnFacing() {
    if (session != TutorialSession.session2) return;
    if (s2 != S2Phase.waitTurn && s2 != S2Phase.interceptHit) return;
    if (!turnWindowOpen) {
      _failS2('太早喇 — 等敵氣勢夠先拖槍對敵');
      return;
    }
    tipText = '拖槍兵向敵騎 — 跟手指轉面，槍尖對住先迎擊';
    tipSkippable = false;
    notifyListeners();
  }

  /// Soft Lock: player marched spear so tip faces the charging enemy.
  void onSpearAimedByMove() {
    if (session != TutorialSession.session2) return;
    if (s2 != S2Phase.waitTurn && s2 != S2Phase.interceptHit) return;
    if (!turnWindowOpen) return;
    if (facingCorrect) return;
    facingCorrect = true;
    s2 = S2Phase.interceptHit;
    tipText = '方向轉咗，槍頭金光留到打中 — 等敵氣勢撞尖就迎擊';
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
      s2 = S2Phase.bowTeach;
      tipText = '槍過關！下一招弓教學：點己方弓兵，停穩蓄勢自動射（唔好拖走）';
      tipSkippable = false;
      notifyListeners();
    } else {
      _failS2('槍尖未對敵 — 拖槍對住敵先');
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

  void onSelectBow() {
    if (session != TutorialSession.session2 || s2 != S2Phase.bowTeach) return;
    tipText = '停穩 — 蓄勢亮咗就自動射（郁就取消）';
    tipSkippable = false;
    notifyListeners();
  }

  /// Soft Lock Field1: standing bow auto-shot completed.
  void onBowShot() {
    if (session != TutorialSession.session2 || s2 != S2Phase.bowTeach) return;
    if (!interceptDone) return;
    s2 = S2Phase.returnCity;
    tipText = '弓過關！最後回城：拖任一己方入底「歸城區」';
    tipSkippable = false;
    notifyListeners();
  }

  /// A 計略 cast that spent 士氣. Clears 用計得宜. On 回城 it is flavour only.
  void onStrategy() {
    if (session != TutorialSession.session2) return;
    if (s2 == S2Phase.strategyOrReturn) {
      // Shot stills: stratagem counts as the old either/or gate.
      if (!interceptDone) return;
      strategyOrReturnDone = true;
      _passS2();
      return;
    }
    if (s2 == S2Phase.strategyTeach) {
      if (!interceptDone) return;
      _passS2();
      return;
    }
    // 計略 before 回城 does not skip it — tip stays on 回城.
    if (s2 == S2Phase.returnCity) {
      tipText = '計略用咗卡面士氣，但要先拖返歸城區，下一課先教用計';
      tipSkippable = false;
      notifyListeners();
    }
  }

  void onReturnCity() {
    if (session != TutorialSession.session2) return;
    if (s2 != S2Phase.returnCity && s2 != S2Phase.strategyOrReturn) return;
    if (!interceptDone) return;
    strategyOrReturnDone = true;
    if (s2 == S2Phase.strategyOrReturn) {
      // Shot stills keep the old either/or close.
      _passS2();
      return;
    }
    s2 = S2Phase.strategyTeach;
    tipText = '回城過關！最後用計得宜：點武將睇計略範圍，消耗士氣放計略';
    tipSkippable = false;
    notifyListeners();
  }

  void _passS2() {
    s2 = S2Phase.tipDone;
    tipText = '戰鬥教學搞掂！撳「跳過」去選勢力';
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
    tipText = '戰鬥教學搞掂！撳「跳過」去選勢力';
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
    tipText = '拖返己城帶搞掂（或撳計略・shot）';
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
    tipText = '蓄緊中 — 場同 Watch 都未見青白環';
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
    tipText = '蓄緊中 — 未亮零青環；部隊跟落點行，唔會瞬移';
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

  /// Proof: near-enemy bump without cyan aura — no 突撃 success.
  void forceChargeNoAuraBump() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.dragGuide;
    phaseC = 0;
    auraReady = false;
    didDragDrop = false;
    tipText = '未見光環撞敵 = 普通近戰 — 唔會突撃';
    tipSkippable = false;
    failed = false;
    failReason = null;
    notifyListeners();
  }

  /// Proof: contact with full aura — 突撃 flash.
  void forceChargeAuraHit() {
    shotPassMode = true;
    session = TutorialSession.session1;
    s1 = S1Phase.tipNext;
    phaseC = 1.0;
    auraReady = true;
    didDragDrop = true;
    tipText = '光環＋接觸 → 自動突撃';
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
