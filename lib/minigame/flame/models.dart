enum FlameMode { herb, smith, haggling, courier, dance, garden }

class GameHudState {
  GameHudState({required this.seconds, required this.score, required this.combo});
  final int seconds;
  final int score;
  final int combo;
}
