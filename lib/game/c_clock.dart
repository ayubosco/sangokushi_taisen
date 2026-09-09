/// Match clock: 99C ≈ 5:00 wall ⇒ 1C ≈ 3.03s.
class CClock {
  static const int matchC = 99;
  static const double secondsPerC = 3.03;

  double _elapsedSeconds = 0;
  bool running = true;

  int get remainingC {
    final used = (_elapsedSeconds / secondsPerC).floor();
    final left = matchC - used;
    return left < 0 ? 0 : left;
  }

  bool get finished => remainingC <= 0;

  void update(double dt) {
    if (!running || finished) return;
    _elapsedSeconds += dt;
  }

  void reset() {
    _elapsedSeconds = 0;
    running = true;
  }

  void pause() => running = false;

  void resume() => running = true;
}
