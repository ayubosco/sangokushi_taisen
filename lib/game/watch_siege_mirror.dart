import 'package:flutter/material.dart';

/// Same-frame Watch read of one field siege-prep gauge.
///
/// VFX-01: this is the live telegraph of the SGE-01 gauge (fill, pause, bow
/// slow, gate/wall). It is not a demo [AWindowKind] plate.
class WatchSiegePrepMirror {
  const WatchSiegePrepMirror({
    required this.index,
    required this.fill01,
    required this.pause,
    required this.slowed,
    required this.face,
    required this.anchor,
  });

  final int index;

  /// 0–1 yellow fill. Same number the field gauge paints this frame.
  final double fill01;

  /// move / ransen / ally while the field held the gauge. Empty while it fills.
  final String pause;

  /// Opposing bow inside the existing range slowed this frame's fill.
  final bool slowed;

  /// gate / wall while the gauge is up.
  final String face;

  /// Watch-band point of the body. Moves when the field body moves.
  final Offset anchor;

  bool get paused => pause.isNotEmpty;

  String get prepTag => 'siege-prep:${fill01.toStringAsFixed(4)}';
  String get pauseTag => 'siege-pause:$pause';
  String get slowTag => 'siege-slow';
  String get faceTag => 'siege-$face';
  String get anchorTag =>
      'siege-at:${anchor.dx.toStringAsFixed(1)},${anchor.dy.toStringAsFixed(1)}';
}

/// A siege body does not wear the cycling charge / 迎擊 / bow poster.
bool watchPaintsOwnDemoPlate({required bool ownIsSiege}) => !ownIsSiege;
