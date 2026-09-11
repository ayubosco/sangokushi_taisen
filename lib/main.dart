import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/faction_colors.dart';
import 'game/taisen_game.dart';
import 'game/tutorial_controller.dart';
import 'data/card_models.dart';
import 'ui/card_detail_sheet.dart';

/// dart-define: TUTORIAL_SHOT=s1pass|s2pass|s1aura|s2coach for Simulator captures.
const String kTutorialShot = String.fromEnvironment('TUTORIAL_SHOT', defaultValue: '');

/// dart-define: DEMO_SHOT=splash|bingfa|s1|match — Simulator readability captures.
const String kDemoShot = String.fromEnvironment('DEMO_SHOT', defaultValue: '');

/// dart-define: FEEL_SHOT=drag-live|drag-hit|drag-samefaction|drag-aura|intercept|intercept-window|bow|bow-idle|bow-attack|cav-idle|cav-attack|stratagem|castle|spear-idle|spear-attack.
/// drag-live/mid-drag；drag-hit post-突撃；intercept-window = 敵オーラ≥1C 轉身窗；bow = 停~1C 蓄勢；cav/bow-*-sheet idle|attack.
/// Title lock: on-screen art = branding PNG lockup (三國＋手指＋大戰). Oral/CFBundleDisplayName may stay「三國指大戰」; never Sega「三國志大戦」. Never draw「指」glyph in title art.
const String kFeelShot = String.fromEnvironment('FEEL_SHOT', defaultValue: '');

/// dart-define: LIVE_VERIFY=s2|bow — clock runs (no FEEL freeze); log HUD C for UIUX manual count.
const String kLiveVerify = String.fromEnvironment('LIVE_VERIFY', defaultValue: '');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const SangokushiApp());
}

class SangokushiApp extends StatelessWidget {
  const SangokushiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '三國指大戰',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FactionColors.lacquer,
        colorScheme: const ColorScheme.dark(
          primary: FactionColors.gold,
          secondary: FactionColors.shu,
        ),
      ),
      home: const AppRoot(),
    );
  }
}

enum _AppStage { splash, bingfaPick, tutorial, factionPick, match }

/// Cosmetic 兵法 stubs — names + blurbs only; no combat formulas.
class BingfaOption {
  const BingfaOption({required this.id, required this.name, required this.blurb});
  final String id;
  final String name;
  final String blurb;

  static const all = <BingfaOption>[
    BingfaOption(id: 'huoji', name: '火計', blurb: '開局佈火勢（暫：純展示，未計傷害）'),
    BingfaOption(id: 'fubing', name: '伏兵', blurb: '埋伏一隊（暫：純展示，未改數值）'),
    BingfaOption(id: 'yuanjun', name: '援軍', blurb: '呼喚援軍氣勢（暫：純展示，未出兵）'),
  ];
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late _AppStage _stage;
  Faction? _pickedFaction;
  String? _selectedBingfa; // display name, or null if skipped/unused
  bool _bingfaConsumed = false;

  @override
  void initState() {
    super.initState();
    _stage = _initialStage();
    const feelMatch = kFeelShot == 'castle' ||
        kFeelShot == 'bow' ||
        kFeelShot == 'bow-idle' ||
        kFeelShot == 'bow-attack' ||
        kFeelShot == 'cav-idle' ||
        kFeelShot == 'cav-attack';
    if (kLiveVerify == 'bow' || kDemoShot == 'match' || feelMatch) {
      _selectedBingfa = '火計';
      _pickedFaction = Faction.shu;
    } else if (kLiveVerify == 's2' || kDemoShot == 's1' || kTutorialShot.isNotEmpty || kFeelShot.isNotEmpty) {
      _selectedBingfa = '火計';
    }
  }

  _AppStage _initialStage() {
    if (kLiveVerify == 'bow') return _AppStage.match;
    if (kLiveVerify == 's2') return _AppStage.tutorial;
    if (kDemoShot == 'splash') return _AppStage.splash;
    if (kDemoShot == 'bingfa') return _AppStage.bingfaPick;
    if (kFeelShot == 'castle' ||
        kFeelShot == 'bow' ||
        kFeelShot == 'bow-idle' ||
        kFeelShot == 'bow-attack' ||
        kFeelShot == 'cav-idle' ||
        kFeelShot == 'cav-attack' ||
        kDemoShot == 'match') {
      return _AppStage.match;
    }
    if (kDemoShot == 's1' || kTutorialShot.isNotEmpty || kFeelShot.isNotEmpty) {
      return _AppStage.tutorial;
    }
    // Simulator demo default: splash → 兵法 → tutorial
    return _AppStage.splash;
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _AppStage.splash:
        return TitleSplash(
          onContinue: () => setState(() => _stage = _AppStage.bingfaPick),
        );
      case _AppStage.bingfaPick:
        return BingfaPickScreen(
          onPicked: (name) {
            _selectedBingfa = name;
            _bingfaConsumed = false;
            setState(() => _stage = _AppStage.tutorial);
          },
          onSkip: () {
            _selectedBingfa = null;
            _bingfaConsumed = false;
            setState(() => _stage = _AppStage.tutorial);
          },
        );
      case _AppStage.tutorial:
        return TutorialShell(
          bingfaLabel: _bingfaStatusLabel(),
          onComplete: () => setState(() => _stage = _AppStage.factionPick),
        );
      case _AppStage.factionPick:
        return FactionPickStub(
          onPicked: (f) {
            _pickedFaction = f;
            setState(() => _stage = _AppStage.match);
          },
        );
      case _AppStage.match:
        return MatchShell(
          faction: _pickedFaction ?? Faction.shu,
          bingfaLabel: _bingfaStatusLabel(),
        );
    }
  }

  String? _bingfaStatusLabel() {
    if (_selectedBingfa == null) return null;
    if (_bingfaConsumed) return '兵法已用';
    return '兵法：$_selectedBingfa';
  }
}

/// Black lacquer + gold opening title.
class TitleSplash extends StatelessWidget {
  const TitleSplash({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FactionColors.lacquer,
      body: SafeArea(
        child: InkWell(
          onTap: onContinue,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Image.asset(
                    'assets/branding/sangokushi-yubi-title-v2.png',
                    height: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '三國',
                          style: TextStyle(
                            color: FactionColors.gold,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.touch_app, color: FactionColors.gold, size: 32),
                        ),
                        Text(
                          '大戰',
                          style: TextStyle(
                            color: FactionColors.gold,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '教學場 · 兵法 · 指尖對陣',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 48),
                const Text(
                  '輕觸繼續',
                  style: TextStyle(color: FactionColors.gold, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Start-of-match 兵法 pick — big gold-framed cards (not a bottom-bar button).
class BingfaPickScreen extends StatelessWidget {
  const BingfaPickScreen({super.key, required this.onPicked, required this.onSkip});
  final ValueChanged<String> onPicked;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FactionColors.lacquer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: FactionColors.gold, width: 2.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '兵法',
                    style: TextStyle(
                      color: FactionColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '每場只揀一次（開局）· 暫為展示，未計傷害',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: BingfaOption.all.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final o = BingfaOption.all[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onPicked(o.name),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: FactionColors.gold, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: FactionColors.gold.withValues(alpha: 0.18),
                                blurRadius: 10,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.name,
                                style: const TextStyle(
                                  color: FactionColors.gold,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                o.blurb,
                                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: onSkip,
                child: const Text('今場不用兵法', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TutorialShell extends StatefulWidget {
  const TutorialShell({super.key, required this.onComplete, this.bingfaLabel});
  final VoidCallback onComplete;
  final String? bingfaLabel;

  @override
  State<TutorialShell> createState() => _TutorialShellState();
}

class _TutorialShellState extends State<TutorialShell> {
  late final TutorialController _tutorial;
  late final TaisenGame _game;
  bool _fieldReady = false;
  bool _showSessionBanner = true;
  TutorialSession? _bannerFor;

  @override
  void initState() {
    super.initState();
    _tutorial = TutorialController();
    _game = TaisenGame(tutorial: _tutorial);
    // Pause before first Flame tick so tutorial/shots never show drained C.
    _game.clock.pause();
    _game.onRequestDetail = (card) => showCardDetailSheet(context, card);
    _game.onTutorialChanged = () {
      if (!mounted) return;
      _maybeShowSessionBanner();
      setState(() {});
      if (_tutorial.session == TutorialSession.complete && !kTutorialShot.startsWith('s')) {
        widget.onComplete();
      }
    };
    _tutorial.addListener(() {
      if (!mounted) return;
      _maybeShowSessionBanner();
      setState(() {});
      if (_tutorial.session == TutorialSession.complete && kTutorialShot.isEmpty) {
        widget.onComplete();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (kFeelShot == 'drag-live') {
        // Mid-drag freeze: guide line + hard enemy outline (tip cannot skip drag).
        _game.setupFeelDragLivePose();
        _tutorial.forceFeelDragLive();
        _bannerFor = TutorialSession.session1;
        _showSessionBanner = true;
      } else if (kFeelShot == 'drag-samefaction') {
        // Design re-check: Wei blue vs Wei blue mid-drag — outline+arrow must carry ID.
        _game.setupFeelDragSameFactionPose();
        _tutorial.forceFeelDragLive();
        _bannerFor = TutorialSession.session1;
        _showSessionBanner = true;
      } else if (kFeelShot == 'drag-hit') {
        // Post-hit after select→drag→drop→aura≥1C→突撃.
        _game.setupFeelDragHitPose();
        _tutorial.forceFeelDragHit();
        _bannerFor = TutorialSession.session1;
        _showSessionBanner = false;
      } else if (kFeelShot == 'drag-aura' || kTutorialShot == 's1aura' || kDemoShot == 's1') {
        // Layout lock: keep enemy on lower field; drag guide + bright aura.
        _game.setupSession1Field();
        if (kFeelShot == 'drag-aura') {
          _tutorial.forceFeelDragAura();
        } else {
          _tutorial.forceSession1AuraGate();
        }
        if (_game.tutorialOwnIndex != null) {
          _game.fieldPos[_game.tutorialOwnIndex!] = _game.dropGuidePoint;
          _game.selectedIndex = _game.tutorialOwnIndex;
        }
        _game.watchKind = AWindowKind.charge;
        _game.dragging = true;
        if (_game.tutorialOwnIndex != null) {
          _game.dragFrom = _game.tokenCenter(_game.tutorialOwnIndex!);
          _game.dragTo = _game.dropGuidePoint;
        }
        _bannerFor = TutorialSession.session1;
        _showSessionBanner = true;
      } else if (kFeelShot == 'spear-idle') {
        _game.setupFeelSpearIdlePose();
        _tutorial.forceFeelInterceptWindow();
        _game.watchKind = AWindowKind.intercept;
        _bannerFor = TutorialSession.session2;
        _showSessionBanner = false;
      } else if (kFeelShot == 'spear-attack') {
        _game.setupFeelSpearAttackPose();
        _tutorial.forceFeelInterceptWindow();
        _game.watchKind = AWindowKind.intercept;
        _bannerFor = TutorialSession.session2;
        _showSessionBanner = false;
      } else if (kFeelShot == 'intercept-window') {
        _game.setupFeelInterceptWindowPose();
        _tutorial.forceFeelInterceptWindow();
        _game.watchKind = AWindowKind.intercept;
        _bannerFor = TutorialSession.session2;
        _showSessionBanner = true;
      } else if (kFeelShot == 'intercept') {
        _game.setupSession2Field();
        _tutorial.forceFeelIntercept();
        _game.watchKind = AWindowKind.intercept;
        _game.flashHit(_game.tutorialOwnIndex ?? 0, '迎擊');
        _bannerFor = TutorialSession.session2;
        _showSessionBanner = true;
      } else if (kFeelShot == 'stratagem' || kTutorialShot == 's2coach') {
        _game.setupSession2Field();
        _tutorial.forceFeelStratagem();
        _game.selectedIndex = _game.tutorialOwnIndex;
        _game.watchKind = AWindowKind.intercept;
        _game.triggerStrategyFx(notifyTutorial: false);
        _bannerFor = TutorialSession.session2;
        _showSessionBanner = true;
      } else if (kTutorialShot == 's1pass') {
        _game.setupSession1Field();
        _tutorial.forceSession1Pass();
        // Keep enemy visible (layout lock); move own to drop for pass pose.
        if (_game.tutorialOwnIndex != null) {
          _game.fieldPos[_game.tutorialOwnIndex!] = _game.dropGuidePoint;
        }
        _game.flashHit(_game.tutorialOwnIndex ?? 0, '突撃');
        _showSessionBanner = false;
      } else if (kTutorialShot == 's2pass') {
        _game.setupSession2Field();
        _tutorial.forceSession2Pass();
        _game.flashHit(_game.tutorialOwnIndex ?? 0, '迎擊');
        _game.triggerStrategyFx();
        _showSessionBanner = false;
      } else if (kLiveVerify == 's2') {
        _tutorial.resetToSession2();
        _game.setupSession2Field();
        _bannerFor = TutorialSession.session2;
        _showSessionBanner = true;
      } else {
        _tutorial.resetToSession1();
        _game.setupSession1Field();
        _bannerFor = TutorialSession.session1;
        _showSessionBanner = true;
      }
      // Freeze C only for FEEL_SHOT / TUTORIAL_SHOT / DEMO_SHOT captures.
      // Free tutorial play keeps HUD clock running so player can count ≥1C / ~1C.
      _game.clock.reset();
      // LIVE_VERIFY keeps C ticking for manual HUD count (≥1C / ~1C).
      final freezeClock = kLiveVerify.isEmpty &&
          (kFeelShot.isNotEmpty || kTutorialShot.isNotEmpty || kDemoShot.isNotEmpty);
      if (freezeClock) {
        _game.clock.pause();
      } else {
        _game.clock.resume();
      }
      if (kLiveVerify == 's2') {
        // ignore: avoid_print
        print('VERIFY_S2 startC=${_game.clock.remainingC} phase=${_tutorial.s2}');
      }
      setState(() => _fieldReady = true);
      // Auto-hide session banner after a beat (still readable at start).
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        if (kDemoShot == 's1') return; // keep title visible for shot
        setState(() => _showSessionBanner = false);
      });
    });
  }

  void _maybeShowSessionBanner() {
    if (_bannerFor != _tutorial.session &&
        (_tutorial.session == TutorialSession.session1 ||
            _tutorial.session == TutorialSession.session2)) {
      _bannerFor = _tutorial.session;
      _showSessionBanner = true;
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        setState(() => _showSessionBanner = false);
      });
    }
  }

  @override
  void dispose() {
    _tutorial.dispose();
    super.dispose();
  }

  void _onSkipTip() {
    final wasS2Tip = _tutorial.session == TutorialSession.session2 && _tutorial.s2 == S2Phase.tipDone;
    final wasS1Tip = _tutorial.session == TutorialSession.session1 && _tutorial.s1 == S1Phase.tipNext;
    _tutorial.skipTip();
    if (wasS1Tip) {
      _game.setupSession2Field();
      setState(() {});
    }
    if (wasS2Tip || _tutorial.session == TutorialSession.complete) {
      widget.onComplete();
    }
  }

  String get _sessionTitle {
    if (_tutorial.session == TutorialSession.session1) return '教學場1：突撃';
    if (_tutorial.session == TutorialSession.session2) return '教學場2：迎擊';
    return '教學';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Hud(
              game: _game,
              subtitle: _tutorial.session == TutorialSession.session1 ? '場1' : '場2',
              bingfaLabel: widget.bingfaLabel,
            ),
            Expanded(
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      _game.selectOrDetailAt(d.localPosition);
                      setState(() {});
                    },
                    onPanStart: (d) {
                      _game.panStart(d.localPosition);
                      setState(() {});
                    },
                    onPanUpdate: (d) {
                      _game.panUpdate(d.localPosition);
                      setState(() {});
                    },
                    onPanEnd: (d) {
                      _game.panEnd(d.localPosition);
                      setState(() {});
                    },
                    child: GameWidget(game: _game),
                  ),
                  if (_showSessionBanner &&
                      (_tutorial.session == TutorialSession.session1 ||
                          _tutorial.session == TutorialSession.session2))
                    Positioned(
                      top: 10,
                      left: 16,
                      right: 16,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xF00A0A0A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FactionColors.gold, width: 1.6),
                          ),
                          child: Text(
                            _sessionTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: FactionColors.gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_tutorial.tipText != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      // H0: tip overlays field (no permanent 8% height). Bottom bar is sibling below,
                      // so tips never cover 歸城/出陣/詳/計略.
                      bottom: 8,
                      child: _TipBanner(
                        text: _tutorial.tipText!,
                        failed: _tutorial.failed,
                        onSkip: _tutorial.tipSkippable ? _onSkipTip : null,
                      ),
                    ),
                  if (!_fieldReady)
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.black54),
                    ),
                ],
              ),
            ),
            _BottomBar(
              onReturnCity: () {
                _game.triggerReturnCityFx();
                setState(() {});
              },
              onSpawn: () {
                // Tutorial: spawn disabled / no-op (keep button visible)
              },
              onDetail: () {
                final idx = _game.selectedIndex;
                if (idx == null || idx >= _game.field.length) return;
                showCardDetailSheet(context, _game.field[idx]);
              },
              onStrategy: () {
                _game.triggerStrategyFx();
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.text, required this.failed, this.onSkip});
  final String text;
  final bool failed;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: failed ? const Color(0xFF4A1515) : const Color(0xE6121212),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: failed ? Colors.redAccent : FactionColors.gold, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: failed ? Colors.redAccent.shade100 : FactionColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            if (onSkip != null)
              TextButton(
                onPressed: onSkip,
                child: const Text('跳過', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Stub faction color pick → then Cost6 match shell.
class FactionPickStub extends StatelessWidget {
  const FactionPickStub({super.key, required this.onPicked});
  final ValueChanged<Faction> onPicked;

  @override
  Widget build(BuildContext context) {
    final entries = <(Faction, String, Color)>[
      (Faction.wei, '魏', FactionColors.wei),
      (Faction.shu, '蜀', FactionColors.shu),
      (Faction.wu, '吳', FactionColors.wu),
      (Faction.other, '他', FactionColors.other),
    ];
    return Scaffold(
      backgroundColor: FactionColors.lacquer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '選擇勢力（暫）',
                style: TextStyle(color: FactionColors.gold, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '之後進入 Cost6 對局殼',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final e in entries)
                    SizedBox(
                      width: 140,
                      height: 64,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: e.$3,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => onPicked(e.$1),
                        child: Text(e.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchShell extends StatefulWidget {
  const MatchShell({
    super.key,
    this.faction = Faction.shu,
    this.bingfaLabel,
  });
  final Faction faction;
  final String? bingfaLabel;

  @override
  State<MatchShell> createState() => _MatchShellState();
}

class _MatchShellState extends State<MatchShell> {
  late final TaisenGame _game;
  int _spawnCursor = 0;

  @override
  void initState() {
    super.initState();
    _game = TaisenGame();
    _game.onRequestDetail = (card) => showCardDetailSheet(context, card);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kFeelShot == 'castle') {
        _game.setupFeelCastleField();
        // 返城 float held for shot (no combat numbers).
      } else if (kLiveVerify == 'bow') {
        _game.setupMatchDemoField();
        _game.clock.reset();
        _game.clock.resume();
        // Start bow windup on own bow token for ~1C live count.
        for (var i = 0; i < _game.field.length; i++) {
          if (!_game.fieldIsEnemy[i] && _game.field[i].troop == TroopType.bow) {
            _game.selectOrDetailAt(_game.tokenCenter(i));
            break;
          }
        }
        // ignore: avoid_print
        print('VERIFY_BOW startC=${_game.clock.remainingC} windup=0');
      } else if (kFeelShot == 'bow') {
        _game.setupFeelBowWindupPose();
        // Freeze mid-windup for capture; free play match still ticks C.
        _game.clock.reset();
        _game.clock.pause();
      } else if (kFeelShot == 'cav-idle') {
        _game.setupFeelCavalryIdlePose();
        _game.clock.reset();
        _game.clock.pause();
      } else if (kFeelShot == 'cav-attack') {
        _game.setupFeelCavalryAttackPose();
        _game.clock.reset();
        _game.clock.pause();
      } else if (kFeelShot == 'bow-idle') {
        _game.setupFeelBowIdlePose();
        _game.clock.reset();
        _game.clock.pause();
      } else if (kFeelShot == 'bow-attack') {
        _game.setupFeelBowAttackPose();
        _game.clock.reset();
        _game.clock.pause();
      } else {
        _game.setupMatchDemoField();
        if (kLiveVerify.isEmpty && kFeelShot.isEmpty && kDemoShot.isEmpty) {
          _game.clock.reset();
          _game.clock.resume();
        }
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Hud(game: _game, subtitle: 'Cost6', bingfaLabel: widget.bingfaLabel),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  _game.selectOrDetailAt(d.localPosition);
                  setState(() {});
                },
                onPanStart: (d) {
                  _game.panStart(d.localPosition);
                  setState(() {});
                },
                onPanUpdate: (d) {
                  _game.panUpdate(d.localPosition);
                  setState(() {});
                },
                onPanEnd: (d) {
                  _game.panEnd(d.localPosition);
                  setState(() {});
                },
                child: GameWidget(game: _game),
              ),
            ),
            _BottomBar(
              onReturnCity: () {
                _game.triggerReturnCityFx();
                setState(() {});
              },
              onSpawn: () {
                final pool = Cost6Roster.byFaction(widget.faction);
                final list = pool.isEmpty ? Cost6Roster.all : pool;
                final card = list[_spawnCursor % list.length];
                _spawnCursor++;
                if (_game.spawnCard(card)) setState(() {});
              },
              onDetail: () {
                final idx = _game.selectedIndex;
                if (idx == null || idx >= _game.field.length) return;
                showCardDetailSheet(context, _game.field[idx]);
              },
              onStrategy: () {
                _game.triggerStrategyFx();
                // Cosmetic: using 計略 does not consume 兵法; stub only.
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, this.subtitle, this.bingfaLabel});
  final TaisenGame game;
  final String? subtitle;
  final String? bingfaLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 200)),
      builder: (context, _) {
        final c = game.clock.remainingC;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: FactionColors.lacquer,
          child: Row(
            children: [
              Image.asset(
                'assets/branding/sangokushi-yubi-title-v2.png',
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '三國',
                      style: TextStyle(
                        color: FactionColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.touch_app, color: FactionColors.gold, size: 16),
                    ),
                    Text(
                      '大戰',
                      style: TextStyle(
                        color: FactionColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 10),
                Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
              if (bingfaLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FactionColors.gold.withValues(alpha: 0.85)),
                  ),
                  child: Text(
                    bingfaLabel!,
                    style: const TextStyle(
                      color: FactionColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '$c C',
                style: TextStyle(
                  color: (game.clock.running && c <= 10) ? Colors.redAccent : FactionColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onReturnCity,
    required this.onSpawn,
    required this.onDetail,
    required this.onStrategy,
  });

  final VoidCallback onReturnCity;
  final VoidCallback onSpawn;
  final VoidCallback onDetail;
  final VoidCallback onStrategy;

  @override
  Widget build(BuildContext context) {
    const minTap = 48.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      color: FactionColors.lacquer,
      child: Row(
        children: [
          SizedBox(
            width: minTap * 1.8,
            height: minTap,
            child: OutlinedButton(
              onPressed: onReturnCity,
              style: OutlinedButton.styleFrom(
                foregroundColor: FactionColors.gold,
                side: const BorderSide(color: FactionColors.gold),
              ),
              child: const Text('歸城', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: minTap * 1.5,
            height: minTap,
            child: OutlinedButton(
              onPressed: onSpawn,
              style: OutlinedButton.styleFrom(
                foregroundColor: FactionColors.gold,
                side: const BorderSide(color: FactionColors.gold),
              ),
              child: const Text('出陣', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: minTap,
            height: minTap,
            child: OutlinedButton(
              onPressed: onDetail,
              style: OutlinedButton.styleFrom(
                foregroundColor: FactionColors.gold,
                side: const BorderSide(color: FactionColors.gold),
                padding: EdgeInsets.zero,
              ),
              child: const Text('詳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: minTap * 1.8,
            height: minTap,
            child: ElevatedButton(
              onPressed: onStrategy,
              style: ElevatedButton.styleFrom(
                backgroundColor: FactionColors.gold,
                foregroundColor: FactionColors.lacquer,
                minimumSize: const Size(minTap * 1.8, minTap),
              ),
              child: const Text('計略', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
