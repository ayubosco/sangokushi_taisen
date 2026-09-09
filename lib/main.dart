import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/faction_colors.dart';
import 'game/taisen_game.dart';
import 'game/tutorial_controller.dart';
import 'data/card_models.dart';
import 'ui/card_detail_sheet.dart';

/// dart-define: TUTORIAL_SHOT=s1pass|s2pass for Simulator clear-pass captures.
const String kTutorialShot = String.fromEnvironment('TUTORIAL_SHOT', defaultValue: '');

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

enum _AppStage { tutorial, factionPick, match }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  _AppStage _stage = _AppStage.tutorial;
  Faction? _pickedFaction;

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _AppStage.tutorial:
        return TutorialShell(
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
        return MatchShell(faction: _pickedFaction ?? Faction.shu);
    }
  }
}

class TutorialShell extends StatefulWidget {
  const TutorialShell({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<TutorialShell> createState() => _TutorialShellState();
}

class _TutorialShellState extends State<TutorialShell> {
  late final TutorialController _tutorial;
  late final TaisenGame _game;
  bool _fieldReady = false;

  @override
  void initState() {
    super.initState();
    _tutorial = TutorialController();
    _game = TaisenGame(tutorial: _tutorial);
    _game.onRequestDetail = (card) => showCardDetailSheet(context, card);
    _game.onTutorialChanged = () {
      if (!mounted) return;
      setState(() {});
      if (_tutorial.session == TutorialSession.complete && !kTutorialShot.startsWith('s')) {
        widget.onComplete();
      }
    };
    _tutorial.addListener(() {
      if (!mounted) return;
      setState(() {});
      if (_tutorial.session == TutorialSession.complete && kTutorialShot.isEmpty) {
        widget.onComplete();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (kTutorialShot == 's1pass') {
        _game.setupSession1Field();
        _tutorial.forceSession1Pass();
        // Clear dim Wei/Wu tokens so 趙雲蜀綠 isn't covered by 曹操藍.
        if (_game.field.length > 1) {
          final own = _game.field.first;
          _game.field
            ..clear()
            ..add(own);
          _game.fieldPos
            ..clear()
            ..add(_game.dropGuidePoint);
          _game.tutorialOwnIndex = 0;
        } else if (_game.tutorialOwnIndex != null) {
          _game.fieldPos[_game.tutorialOwnIndex!] = _game.dropGuidePoint;
        }
        _game.flashHit(_game.tutorialOwnIndex ?? 0, '突撃');
      } else if (kTutorialShot == 's2pass') {
        _game.setupSession2Field();
        _tutorial.forceSession2Pass();
        _game.flashHit(_game.tutorialOwnIndex ?? 0, '迎擊');
        _game.triggerStrategyFx();
      } else {
        _tutorial.resetToSession1();
        _game.setupSession1Field();
      }
      // Tutorial HUD: 99C vocabulary — pause so never red 0 C during teach/shots.
      _game.clock.reset();
      _game.clock.pause();
      setState(() => _fieldReady = true);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Hud(game: _game, subtitle: _tutorial.session == TutorialSession.session1 ? '場1' : '場2'),
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
                  if (_tutorial.tipText != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      // Sit above bottom of field stack — bottom bar is sibling below,
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
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
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
  const MatchShell({super.key, this.faction = Faction.shu});
  final Faction faction;

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
      _game.setupMatchDemoField();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Hud(game: _game, subtitle: 'Cost6'),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  _game.selectOrDetailAt(d.localPosition);
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
  const _Hud({required this.game, this.subtitle});
  final TaisenGame game;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 200)),
      builder: (context, _) {
        final c = game.clock.remainingC;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: FactionColors.lacquer,
          child: Row(
            children: [
              Image.asset(
                'assets/brand/sangokushi-yubi-title-v2.png',
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  '三國大戰',
                  style: TextStyle(
                    color: FactionColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 10),
                Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
              const Spacer(),
              Text(
                '$c C',
                style: TextStyle(
                  color: (game.clock.running && c <= 10) ? Colors.redAccent : FactionColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
              child: const Text('歸城'),
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
              child: const Text('出陣'),
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
              child: const Icon(Icons.info_outline, size: 22),
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
              child: const Text('計略'),
            ),
          ),
        ],
      ),
    );
  }
}
