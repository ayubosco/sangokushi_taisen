import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/faction_colors.dart';
import 'game/taisen_game.dart';
import 'data/card_models.dart';
import 'ui/card_detail_sheet.dart';

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
        colorScheme: ColorScheme.dark(
          primary: FactionColors.gold,
          secondary: FactionColors.shu,
        ),
      ),
      home: const MatchShell(),
    );
  }
}

class MatchShell extends StatefulWidget {
  const MatchShell({super.key});

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final zhao = Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun');
      _game.spawnCard(zhao);
      _game.spawnCard(Cost6Roster.all.firstWhere((c) => c.id == 'caocao'));
      _game.selectedIndex = 0;
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await showCardDetailSheet(context, zhao);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Hud(game: _game),
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
                // stub: clear selection / future 歸城
                _game.selectedIndex = null;
                setState(() {});
              },
              onSpawn: () {
                final card = Cost6Roster.all[_spawnCursor % Cost6Roster.all.length];
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
  const _Hud({required this.game});
  final TaisenGame game;

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
                errorBuilder: (_, __, ___) => Text(
                  '三國大戰',
                  style: TextStyle(
                    color: FactionColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$c C',
                style: TextStyle(
                  color: c <= 10 ? Colors.redAccent : FactionColors.gold,
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
    // 計略／歸城 ≥12mm ≈ 48 logical px
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
