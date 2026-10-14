import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Design Soft Lock cue sprites (槍 tip / 迎撃 / 弓蓄勢 / 歸城·返城 / Watch mirrors).
///
/// Assets live under [assetDir] with Flutter resolution folders (`2.0x/`, `3.0x/`).
/// Logical draw sizes follow `sprites/manifest.json` size_pt. Missing art falls
/// through to canvas paint in [TaisenGame] — gameplay never depends on these.
class SoftLockCueBank {
  static const String assetDir = 'assets/fx/soft-lock-cues';

  static const List<String> names = [
    'tip-up',
    'tip-45',
    'tip-scrape',
    'bow-halo',
    'bow-aim',
    'bow-aim-drawn',
    'bow-arrow',
    'fly-geigeki',
    'watch-tip',
    'watch-bow',
    'castle-glow',
    'fly-fancheng',
    'fly-guicheng',
  ];

  /// Logical pt sizes from Design manifest (1x).
  static const Map<String, Size> sizePt = {
    'tip-up': Size(36, 52),
    'tip-45': Size(36, 52),
    'tip-scrape': Size(72, 44),
    'bow-halo': Size(72, 72),
    'bow-aim': Size(18, 120),
    'bow-aim-drawn': Size(16, 110),
    'bow-arrow': Size(64, 28),
    'fly-geigeki': Size(88, 44),
    'watch-tip': Size(28, 38),
    'watch-bow': Size(34, 34),
    'castle-glow': Size(402, 66.67),
    'fly-fancheng': Size(56, 33),
    'fly-guicheng': Size(56, 33),
  };

  /// Anchor inside the sprite in pt (Design manifest). Default = center.
  static const Map<String, Offset> anchorPt = {
    'tip-up': Offset(18, 44.2),
    'tip-45': Offset(12.6, 39),
    'tip-scrape': Offset(36, 22),
    'bow-halo': Offset(36, 36),
    'bow-aim': Offset(9, 120),
    'bow-aim-drawn': Offset(8, 110),
    'bow-arrow': Offset(9.6, 14),
    'fly-geigeki': Offset(44, 22),
    'watch-tip': Offset(14, 19),
    'watch-bow': Offset(17, 17),
    'castle-glow': Offset(201, 33.33),
    'fly-fancheng': Offset(28, 16.5),
    'fly-guicheng': Offset(28, 16.5),
  };

  static const Set<String> additiveBlend = {
    'tip-up',
    'tip-45',
    'tip-scrape',
    'watch-tip',
  };

  final Map<String, ui.Image> _images = {};

  bool get isLoaded => _images.length == names.length;

  bool has(String name) => _images.containsKey(name);

  ui.Image? image(String name) => _images[name];

  Future<void> loadAll() async {
    for (final name in names) {
      if (_images.containsKey(name)) continue;
      final img = await _loadBest(name);
      if (img != null) _images[name] = img;
    }
  }

  /// Prefer AssetImage (DPR → 2.0x / 3.0x). Fall back to rootBundle 1x.
  Future<ui.Image?> _loadBest(String name) async {
    final logical = '$assetDir/$name.png';
    try {
      return await _loadViaAssetImage(logical);
    } catch (_) {
      // fall through
    }
    try {
      final data = await rootBundle.load(logical);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _loadViaAssetImage(String assetPath) async {
    final dpr = ui.PlatformDispatcher.instance.views.isEmpty
        ? 3.0
        : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final provider = AssetImage(assetPath);
    final config = ImageConfiguration(
      bundle: rootBundle,
      devicePixelRatio: dpr < 1.5 ? 3.0 : dpr, // headless tests: prefer crisp 3x
    );
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(config);
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      completer.complete(info.image.clone());
      stream.removeListener(listener);
    }, onError: (Object e, StackTrace? st) {
      completer.completeError(e, st);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  /// Draw [name] so its Design anchor sits on [worldAnchor].
  /// Returns false when the sprite is missing (caller keeps canvas fallback).
  bool draw(
    Canvas canvas,
    String name,
    Offset worldAnchor, {
    double alpha = 1,
    double rotation = 0,
    double scale = 1,
  }) {
    final img = _images[name];
    if (img == null) return false;
    final sz = sizePt[name] ?? Size(img.width.toDouble(), img.height.toDouble());
    final anchor = anchorPt[name] ?? Offset(sz.width / 2, sz.height / 2);
    final blend = additiveBlend.contains(name) ? BlendMode.plus : BlendMode.srcOver;
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
      ..blendMode = blend
      ..filterQuality = FilterQuality.medium;

    canvas.save();
    canvas.translate(worldAnchor.dx, worldAnchor.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (scale != 1) canvas.scale(scale);
    canvas.translate(-anchor.dx, -anchor.dy);
    final dst = Rect.fromLTWH(0, 0, sz.width, sz.height);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      paint,
    );
    canvas.restore();
    return true;
  }

  /// Stretch [name] into [dst] (castle-glow band).
  bool drawRect(Canvas canvas, String name, Rect dst, {double alpha = 1}) {
    final img = _images[name];
    if (img == null) return false;
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
      ..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      paint,
    );
    return true;
  }
}
