import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/c_clock.dart';
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

  @override
  void initState() {
    super.initState();
    _game = TaisenGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Hud(game: _game),
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Image.asset(
                  'assets/icons/cost6-weapon-icons.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Expanded(
              child: GameWidget(game: _game),
            ),
            _BottomBar(
              onSpawn: () {
                _game.spawnPlaceholderUnit();
                setState(() {});
              },
              onStrategy: () {
                _game.triggerStrategyFx();
                setState(() {});
              },
              onCharge: () {
                _game.triggerChargeAuraDemo();
                setState(() {});
              },
              onDetail: () {
                final zhao = Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun');
                showCardDetailSheet(context, zhao);
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
              const SizedBox(width: 8),
              Text(
                '1C=${CClock.secondsPerC}s',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
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
    required this.onSpawn,
    required this.onStrategy,
    required this.onCharge,
    required this.onDetail,
  });

  final VoidCallback onSpawn;
  final VoidCallback onStrategy;
  final VoidCallback onCharge;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    // ≥12mm ≈ 48 logical px minimum for 計略 / 歸城
    const minTap = 48.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: FactionColors.lacquer,
      child: Row(
        children: [
          SizedBox(
            width: minTap * 1.6,
            height: minTap,
            child: OutlinedButton(
              onPressed: onSpawn,
              style: OutlinedButton.styleFrom(
                foregroundColor: FactionColors.gold,
                side: BorderSide(color: FactionColors.gold),
              ),
              child: const Text('出陣'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: minTap * 1.6,
            height: minTap,
            child: OutlinedButton(
              onPressed: onCharge,
              style: OutlinedButton.styleFrom(
                foregroundColor: FactionColors.wei,
                side: BorderSide(color: FactionColors.wei),
              ),
              child: const Text('オーラ'),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: minTap * 1.4,
            height: minTap,
            child: OutlinedButton(
              onPressed: onDetail,
              style: OutlinedButton.styleFrom(
                foregroundColor: FactionColors.gold,
                side: const BorderSide(color: FactionColors.gold),
              ),
              child: const Text('詳'),
            ),
          ),
          const SizedBox(width: 8),
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
