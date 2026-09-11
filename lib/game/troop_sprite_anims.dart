import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../data/card_models.dart';

/// Field troop pose rows on Design 4×4 sheets (idle / move / attack / recover).
enum TroopAnimPose { idle, move, attack, recover }

/// Flame [SpriteAnimation] bank for per-troop ortho sheets.
///
/// Sheet layout (Design): 1280×720 → 4×4 cells of 320×180 (landscape packing).
/// Figures sit in a ~110–130px window that slides per column — we crop that
/// window so portrait 5:8 tokens stay readable (Bosco 0.11–0.13 width).
/// Independent FX (aura / tip / flytext) stay outside the sheet.
class TroopSpriteBank {
  static const double cellW = 320;
  static const double cellH = 180;
  static const int columns = 4;

  /// Content window inside each landscape cell (portrait-ish crop for field).
  static const double contentW = 128;
  static const double contentH = 180;

  /// Per-column left inset of the figure window inside a 320 cell
  /// (sheet packs walk frames left←right across the cell).
  static const List<double> contentLeftInCell = [196, 128, 60, 0];

  /// Full loop ≈ 0.8s ≈ 0.26C — readable, under ≤0.5–1C Design lock.
  static const double stepIdle = 0.20;
  static const double stepMove = 0.16;
  static const double stepAttack = 0.14;
  static const double stepRecover = 0.18;

  final Map<TroopType, ui.Image> _images = {};
  final Map<TroopType, Map<TroopAnimPose, SpriteAnimation>> _anims = {};
  final Map<TroopType, Map<TroopAnimPose, SpriteAnimationTicker>> _tickers = {};

  bool has(TroopType troop) => _anims.containsKey(troop);

  Future<void> loadAll() async {
    await _loadTroop(
      TroopType.spear,
      'assets/sprites/troop-spear-sheet-v1.png',
      keyBlack: false,
    );
    await _loadTroop(
      TroopType.infantry,
      'assets/sprites/troop-dao-sheet-v1.png',
      keyBlack: true,
    );
    await _loadTroop(
      TroopType.siege,
      'assets/sprites/troop-dao-sheet-v1.png',
      keyBlack: true,
      reuseOf: TroopType.infantry,
    );
    await _loadTroop(
      TroopType.bow,
      'assets/sprites/troop-bow-sheet-v1.png',
      keyBlack: true,
    );
    await _loadTroop(
      TroopType.cavalry,
      'assets/sprites/troop-cavalry-sheet-v1.png',
      keyBlack: false,
    );
  }

  Future<void> _loadTroop(
    TroopType troop,
    String assetPath, {
    required bool keyBlack,
    TroopType? reuseOf,
  }) async {
    if (reuseOf != null && _anims.containsKey(reuseOf)) {
      _images[troop] = _images[reuseOf]!;
      _anims[troop] = Map.of(_anims[reuseOf]!);
      _tickers[troop] = {
        for (final e in _anims[troop]!.entries) e.key: e.value.createTicker(),
      };
      return;
    }

    final image = keyBlack
        ? await _loadImageKeyNearBlack(assetPath)
        : await _loadImage(assetPath);
    _images[troop] = image;

    final poses = <TroopAnimPose, SpriteAnimation>{
      TroopAnimPose.idle: _rowAnimation(image, row: 0, stepTime: stepIdle),
      TroopAnimPose.move: _rowAnimation(image, row: 1, stepTime: stepMove),
      TroopAnimPose.attack: _rowAnimation(image, row: 2, stepTime: stepAttack),
      TroopAnimPose.recover: _rowAnimation(image, row: 3, stepTime: stepRecover),
    };
    _anims[troop] = poses;
    _tickers[troop] = {
      for (final e in poses.entries) e.key: e.value.createTicker(),
    };
  }

  SpriteAnimation _rowAnimation(ui.Image image, {required int row, required double stepTime}) {
    final frames = <Sprite>[];
    for (var col = 0; col < columns; col++) {
      final left = col * cellW + contentLeftInCell[col];
      final top = row * cellH;
      frames.add(
        Sprite(
          image,
          srcPosition: Vector2(left, top),
          srcSize: Vector2(contentW, contentH),
        ),
      );
    }
    return SpriteAnimation.spriteList(frames, stepTime: stepTime);
  }

  void update(double dt) {
    for (final byPose in _tickers.values) {
      for (final t in byPose.values) {
        t.update(dt);
      }
    }
  }

  Sprite? currentSprite(TroopType troop, TroopAnimPose pose) {
    return _tickers[troop]?[pose]?.getSprite();
  }

  /// Fit current frame into [dest]. Cover keeps spear tip readable on small tokens.
  void render(
    ui.Canvas canvas,
    ui.Rect dest,
    TroopType troop,
    TroopAnimPose pose, {
    double opacity = 1.0,
    BoxFit fit = BoxFit.cover,
  }) {
    final sprite = currentSprite(troop, pose);
    if (sprite == null) return;
    final srcSize = sprite.srcSize;
    if (srcSize.x <= 0 || srcSize.y <= 0) return;
    final scale = fit == BoxFit.cover
        ? (dest.width / srcSize.x > dest.height / srcSize.y
            ? dest.width / srcSize.x
            : dest.height / srcSize.y)
        : (dest.width / srcSize.x < dest.height / srcSize.y
            ? dest.width / srcSize.x
            : dest.height / srcSize.y);
    final dw = srcSize.x * scale;
    final dh = srcSize.y * scale;
    final dx = dest.left + (dest.width - dw) / 2;
    final dy = dest.top + (dest.height - dh) / 2;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));
    canvas.save();
    canvas.clipRRect(
      ui.RRect.fromRectAndRadius(dest, ui.Radius.circular(dest.width * 0.08)),
    );
    sprite.render(
      canvas,
      position: Vector2(dx, dy),
      size: Vector2(dw, dh),
      overridePaint: paint,
    );
    canvas.restore();
  }

  static Future<ui.Image> _loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// RGB sheets with lacquer-black matte → near-black pixels become transparent.
  static Future<ui.Image> _loadImageKeyNearBlack(String assetPath) async {
    final src = await _loadImage(assetPath);
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return src;
    final bytes = bd.buffer.asUint8List();
    final out = Uint8List.fromList(bytes);
    const thr = 18;
    for (var i = 0; i < out.length; i += 4) {
      final r = out[i];
      final g = out[i + 1];
      final b = out[i + 2];
      if (r <= thr && g <= thr && b <= thr) {
        out[i + 3] = 0;
      }
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(out);
    final desc = ui.ImageDescriptor.raw(
      buffer,
      width: src.width,
      height: src.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
